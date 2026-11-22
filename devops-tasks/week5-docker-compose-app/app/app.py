"""Notes API - a small Flask + PostgreSQL service behind Nginx.

Endpoints
  GET  /          service info, the container that answered, total visits
  GET  /health    liveness + database readiness (used by the Docker healthcheck)
  GET  /notes     list notes (newest first)
  POST /notes     create a note: {"text": "..."}
"""

import logging
import os
import socket
from contextlib import contextmanager

import psycopg2
from flask import Flask, jsonify, request
from psycopg2.pool import SimpleConnectionPool

logging.basicConfig(
    level=os.getenv("LOG_LEVEL", "INFO"),
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
)
log = logging.getLogger("notes-api")

APP_VERSION = os.getenv("APP_VERSION", "1.0.0")
HOSTNAME = socket.gethostname()

app = Flask(__name__)
_pool: SimpleConnectionPool | None = None


def get_pool() -> SimpleConnectionPool:
    """Create the connection pool lazily, once per gunicorn worker."""
    global _pool
    if _pool is None:
        _pool = SimpleConnectionPool(
            minconn=1,
            maxconn=int(os.getenv("DB_POOL_MAX", "5")),
            host=os.environ["DB_HOST"],
            port=int(os.getenv("DB_PORT", "5432")),
            dbname=os.environ["DB_NAME"],
            user=os.environ["DB_USER"],
            password=os.environ["DB_PASS"],
            connect_timeout=3,
        )
    return _pool


@contextmanager
def db_cursor():
    """Borrow a connection, commit on success, roll back on error, always return it."""
    pool = get_pool()
    conn = pool.getconn()
    broken = False
    try:
        with conn.cursor() as cur:
            yield cur
        conn.commit()
    except (psycopg2.OperationalError, psycopg2.InterfaceError):
        # The connection died (e.g. Postgres restarted). Do not return it to the
        # pool, otherwise every later request would fail on the same dead socket.
        broken = True
        raise
    except Exception:
        conn.rollback()
        raise
    finally:
        pool.putconn(conn, close=broken or conn.closed != 0)


def init_db() -> None:
    with db_cursor() as cur:
        # Several replicas start at once; concurrent CREATE TABLE IF NOT EXISTS can
        # still collide in the catalog, so serialise schema creation with a lock.
        cur.execute("SELECT pg_advisory_xact_lock(727001)")
        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS visits (
                id         BIGSERIAL PRIMARY KEY,
                host       TEXT        NOT NULL,
                created_at TIMESTAMPTZ NOT NULL DEFAULT now()
            );
            CREATE TABLE IF NOT EXISTS notes (
                id         BIGSERIAL PRIMARY KEY,
                text       TEXT        NOT NULL CHECK (length(text) BETWEEN 1 AND 500),
                created_at TIMESTAMPTZ NOT NULL DEFAULT now()
            );
            """
        )


_db_ready = False


@app.before_request
def ensure_schema() -> None:
    global _db_ready
    if request.path == "/health":  # health must answer 503, not crash, when the DB is down
        return
    if not _db_ready:
        init_db()
        _db_ready = True


@app.get("/")
def index():
    with db_cursor() as cur:
        cur.execute("INSERT INTO visits (host) VALUES (%s)", (HOSTNAME,))
        cur.execute("SELECT count(*) FROM visits")
        total = cur.fetchone()[0]
    return jsonify(service="notes-api", version=APP_VERSION, host=HOSTNAME, visits=total)


@app.get("/health")
def health():
    try:
        with db_cursor() as cur:
            cur.execute("SELECT 1")
        return jsonify(status="ok", db="ok", host=HOSTNAME)
    except psycopg2.Error as exc:
        log.warning("health check failed: %s", exc)
        return jsonify(status="degraded", db="unreachable", host=HOSTNAME), 503


@app.get("/notes")
def list_notes():
    limit = min(request.args.get("limit", default=20, type=int), 100)
    with db_cursor() as cur:
        cur.execute("SELECT id, text, created_at FROM notes ORDER BY id DESC LIMIT %s", (limit,))
        rows = cur.fetchall()
    return jsonify([{"id": r[0], "text": r[1], "created_at": r[2].isoformat()} for r in rows])


@app.post("/notes")
def create_note():
    data = request.get_json(silent=True) or {}
    text = str(data.get("text", "")).strip()
    if not 1 <= len(text) <= 500:
        return jsonify(error="'text' must be 1-500 characters"), 400
    with db_cursor() as cur:
        cur.execute("INSERT INTO notes (text) VALUES (%s) RETURNING id, created_at", (text,))
        note_id, created_at = cur.fetchone()
    log.info("note created id=%s host=%s", note_id, HOSTNAME)
    return jsonify(id=note_id, text=text, created_at=created_at.isoformat()), 201


if __name__ == "__main__":  # local development only; production uses gunicorn
    app.run(host="0.0.0.0", port=5000)  # noqa: S104 - must be reachable inside a container
