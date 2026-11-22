import logging
import socket
from contextlib import asynccontextmanager
from typing import Annotated

from fastapi import Depends, FastAPI, Header, HTTPException, Query, Request
from fastapi.responses import JSONResponse
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app import __version__, schemas, services
from app.config import get_settings
from app.database import Base, engine, get_db

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s %(message)s")
log = logging.getLogger("payfast")

HOSTNAME = socket.gethostname()
DB = Annotated[Session, Depends(get_db)]


@asynccontextmanager
async def lifespan(_: FastAPI):
    # Simple schema creation for a course project; a larger app would use Alembic migrations.
    # Several workers/replicas start at once: on PostgreSQL an advisory lock makes them
    # create the tables one after another instead of colliding in the system catalog.
    with engine.begin() as conn:
        if conn.dialect.name == "postgresql":
            conn.execute(text("SELECT pg_advisory_xact_lock(727002)"))
        Base.metadata.create_all(conn)
    log.info("PayFast Tickets %s started on %s", get_settings().app_version, HOSTNAME)
    yield


app = FastAPI(
    title="PayFast Tickets",
    description="Event ticket booking API · Unit 4 DevOps · Shoxjahon Tuymurodov (23-309)",
    version=__version__,
    lifespan=lifespan,
)


@app.exception_handler(services.NotFound)
async def not_found(_: Request, exc: services.NotFound):
    return JSONResponse(status_code=404, content={"detail": str(exc)})


@app.exception_handler(services.Conflict)
async def conflict(_: Request, exc: services.Conflict):
    return JSONResponse(status_code=409, content={"detail": str(exc)})


# ---------- system ----------
@app.get("/", tags=["system"])
def root():
    return {
        "service": "payfast-tickets",
        "version": get_settings().app_version,
        "host": HOSTNAME,
        "docs": "/docs",
    }


@app.get("/health", tags=["system"])
def health(db: DB):
    try:
        db.execute(text("SELECT 1"))
    except SQLAlchemyError:
        raise HTTPException(status_code=503, detail="database unreachable") from None
    return {"status": "ok", "db": "ok", "host": HOSTNAME}


# ---------- events ----------
@app.post("/events", response_model=schemas.EventOut, status_code=201, tags=["events"])
def create_event(data: schemas.EventCreate, db: DB):
    return services.event_out(db, services.create_event(db, data))


@app.get("/events", response_model=list[schemas.EventOut], tags=["events"])
def list_events(db: DB, limit: int = Query(20, ge=1, le=100), offset: int = Query(0, ge=0)):
    return services.list_events(db, limit=limit, offset=offset)


@app.get("/events/{event_id}", response_model=schemas.EventOut, tags=["events"])
def get_event(event_id: int, db: DB):
    return services.event_out(db, services.get_event(db, event_id))


@app.get("/events/{event_id}/seats", response_model=list[schemas.SeatOut], tags=["events"])
def list_seats(event_id: int, db: DB, available: bool = False):
    return services.list_seats(db, event_id, only_available=available)


# ---------- bookings ----------
@app.post("/bookings", response_model=schemas.BookingOut, status_code=201, tags=["bookings"])
def create_booking(data: schemas.BookingCreate, db: DB):
    return services.create_booking(db, data)


@app.get("/bookings/{booking_id}", response_model=schemas.BookingOut, tags=["bookings"])
def get_booking(booking_id: int, db: DB):
    return services.get_booking(db, booking_id)


@app.post("/bookings/{booking_id}/cancel", response_model=schemas.BookingOut, tags=["bookings"])
def cancel_booking(booking_id: int, db: DB):
    return services.cancel_booking(db, booking_id)


@app.post(
    "/bookings/{booking_id}/pay",
    response_model=schemas.TicketOut,
    status_code=201,
    tags=["payments"],
)
def pay_booking(
    booking_id: int,
    data: schemas.PaymentCreate,
    db: DB,
    idempotency_key: Annotated[str, Header(min_length=8, max_length=100)],
):
    ticket = services.pay_booking(db, booking_id, data, idempotency_key)
    return services.ticket_out(ticket)


# ---------- tickets ----------
@app.get("/tickets/{code}", response_model=schemas.TicketOut, tags=["tickets"])
def get_ticket(code: str, db: DB):
    return services.ticket_out(services.get_ticket(db, code))
