# Architecture decisions

Short records of important choices: context, decision, consequences.

## ADR-001 · Topic: ticket booking

**Context:** the course offers six domains; the project must grow through Docker, CI/CD and Kubernetes until week 14.
**Decision:** ticket booking (event, seat, booking, payment, ticket).
**Consequences:** it has one real concurrency problem — two people buying the same seat — which makes database constraints, scaling and load testing meaningful later.

## ADR-002 · FastAPI + SQLAlchemy 2 + PostgreSQL

**Context:** a small, typed REST API with automatic documentation.
**Decision:** FastAPI (OpenAPI/Swagger at `/docs`), SQLAlchemy 2 ORM, PostgreSQL 16; SQLite only for fast local tests.
**Consequences:** the same tests run against SQLite and PostgreSQL in CI.

## ADR-003 · Double booking is prevented by the database, not by Python

**Context:** with several API replicas behind nginx, a Python check "is the seat free?" followed by an insert is a race: two requests can both see the seat as free.
**Decision:** a partial unique index `uq_active_booking_per_seat` on `bookings(seat_id) WHERE status <> 'CANCELLED'`. The API catches the `IntegrityError` and returns `409 Conflict`.
**Consequences:** correct under any number of replicas. Verified: 50 parallel requests for one seat across 2 replicas → exactly one `201`, 49 × `409`.

## ADR-004 · Payments are idempotent and row-locked

**Context:** clients retry when the network fails; a retry must not charge twice. Two parallel payments must not both succeed.
**Decision:** `Idempotency-Key` header (unique in `payments`); a repeat with the same key returns the same ticket. The booking row is locked with `SELECT … FOR UPDATE` during payment; `payments.booking_id` is unique as a last line of defence.
**Consequences:** verified with 20 parallel payments with different keys → exactly one payment and one ticket.

## ADR-005 · Unpaid bookings expire

**Decision:** a booking holds the seat for `BOOKING_HOLD_MINUTES` (default 15). Expired holds are released before a new booking and when a late payment arrives.
**Consequences:** seats are not blocked forever by abandoned checkouts.

## ADR-006 · Schema creation without migrations (for now)

**Decision:** `Base.metadata.create_all` at start-up.
**Consequences:** simple for the course; any schema change on existing data will need Alembic migrations — planned before the Kubernetes weeks.

## ADR-007 · Container and network layout

**Decision:** multi-stage Dockerfile, non-root user, gunicorn with uvicorn workers; nginx is the only published service (`80`); PostgreSQL sits on an `internal` network; cAdvisor is bound to `127.0.0.1` because Docker-published ports bypass ufw.
**Consequences:** smaller attack surface; `docker compose up --scale api=3` works without changing nginx.
