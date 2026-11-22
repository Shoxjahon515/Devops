"""Business rules live here, not in the HTTP layer, so they can be tested and
reused without FastAPI."""

import string
from datetime import UTC, datetime, timedelta

from sqlalchemy import func, select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app import models, schemas
from app.config import get_settings


class NotFound(Exception):
    pass


class Conflict(Exception):
    pass


def _as_utc(dt: datetime) -> datetime:
    # SQLite returns naive datetimes; PostgreSQL returns aware ones
    return dt if dt.tzinfo else dt.replace(tzinfo=UTC)


def _active_seat_ids(db: Session, event_id: int) -> set[int]:
    rows = db.scalars(
        select(models.Booking.seat_id)
        .join(models.Seat)
        .where(
            models.Seat.event_id == event_id,
            models.Booking.status != models.BookingStatus.CANCELLED,
        )
    )
    return set(rows)


def release_expired_holds(db: Session) -> int:
    """Cancel unpaid bookings whose hold time is over, so the seats are free again."""
    result = db.execute(
        update(models.Booking)
        .where(
            models.Booking.status == models.BookingStatus.PENDING,
            models.Booking.expires_at < datetime.now(UTC),
        )
        .values(status=models.BookingStatus.CANCELLED)
    )
    db.commit()
    return result.rowcount or 0


# ---------- events ----------
def create_event(db: Session, data: schemas.EventCreate) -> models.Event:
    event = models.Event(
        title=data.title, venue=data.venue, starts_at=data.starts_at, price=data.price
    )
    event.seats = [
        models.Seat(row=string.ascii_uppercase[r], number=n)
        for r in range(data.rows)
        for n in range(1, data.seats_per_row + 1)
    ]
    db.add(event)
    db.commit()
    return event


def event_out(db: Session, event: models.Event) -> schemas.EventOut:
    total = db.scalar(select(func.count()).where(models.Seat.event_id == event.id)) or 0
    taken = len(_active_seat_ids(db, event.id))
    return schemas.EventOut(
        id=event.id,
        title=event.title,
        venue=event.venue,
        starts_at=event.starts_at,
        price=event.price,
        total_seats=total,
        available_seats=total - taken,
    )


def list_events(db: Session, limit: int, offset: int) -> list[schemas.EventOut]:
    """One query for the whole page (no N+1): seat and active-booking counts are
    aggregated in SQL instead of two extra queries per event."""
    active = (
        select(models.Booking.seat_id)
        .where(models.Booking.status != models.BookingStatus.CANCELLED)
        .subquery()
    )
    stmt = (
        select(
            models.Event,
            func.count(models.Seat.id).label("total"),
            func.count(active.c.seat_id).label("taken"),
        )
        .join(models.Seat, models.Seat.event_id == models.Event.id, isouter=True)
        .join(active, active.c.seat_id == models.Seat.id, isouter=True)
        .group_by(models.Event.id)
        .order_by(models.Event.starts_at, models.Event.id)
        .limit(limit)
        .offset(offset)
    )
    return [
        schemas.EventOut(
            id=e.id,
            title=e.title,
            venue=e.venue,
            starts_at=e.starts_at,
            price=e.price,
            total_seats=total,
            available_seats=total - taken,
        )
        for e, total, taken in db.execute(stmt)
    ]


def get_event(db: Session, event_id: int) -> models.Event:
    event = db.get(models.Event, event_id)
    if event is None:
        raise NotFound(f"event {event_id} not found")
    return event


def list_seats(db: Session, event_id: int, only_available: bool) -> list[schemas.SeatOut]:
    get_event(db, event_id)
    taken = _active_seat_ids(db, event_id)
    seats = db.scalars(
        select(models.Seat).where(models.Seat.event_id == event_id).order_by(models.Seat.id)
    )
    out = [
        schemas.SeatOut(id=s.id, row=s.row, number=s.number, available=s.id not in taken)
        for s in seats
    ]
    return [s for s in out if s.available] if only_available else out


# ---------- bookings ----------
def create_booking(db: Session, data: schemas.BookingCreate) -> models.Booking:
    seat = db.get(models.Seat, data.seat_id)
    if seat is None:
        raise NotFound(f"seat {data.seat_id} not found")
    if _as_utc(seat.event.starts_at) <= datetime.now(UTC):
        raise Conflict("event has already started")

    release_expired_holds(db)
    booking = models.Booking(
        seat_id=seat.id,
        customer_name=data.customer_name,
        customer_email=str(data.customer_email),
        expires_at=datetime.now(UTC) + timedelta(minutes=get_settings().booking_hold_minutes),
    )
    db.add(booking)
    try:
        db.commit()
    except IntegrityError:
        # the partial unique index rejected a second active booking for this seat
        db.rollback()
        raise Conflict(f"seat {seat.row}{seat.number} is already booked") from None
    return booking


def get_booking(db: Session, booking_id: int) -> models.Booking:
    booking = db.get(models.Booking, booking_id)
    if booking is None:
        raise NotFound(f"booking {booking_id} not found")
    return booking


def cancel_booking(db: Session, booking_id: int) -> models.Booking:
    booking = get_booking(db, booking_id)
    if booking.status == models.BookingStatus.PAID:
        raise Conflict("a paid booking cannot be cancelled here; ask for a refund")
    booking.status = models.BookingStatus.CANCELLED
    db.commit()
    return booking


# ---------- payment + ticket ----------
def pay_booking(
    db: Session, booking_id: int, data: schemas.PaymentCreate, idempotency_key: str
) -> models.Ticket:
    # Retry of an already processed request: return the same ticket, charge nothing
    existing = db.scalar(
        select(models.Payment).where(models.Payment.idempotency_key == idempotency_key)
    )
    if existing is not None:
        if existing.booking_id != booking_id:
            raise Conflict("Idempotency-Key was already used for another booking")
        return existing.booking.ticket

    # Lock the booking row so two parallel payments cannot both pass the checks
    booking = db.scalar(
        select(models.Booking).where(models.Booking.id == booking_id).with_for_update()
    )
    if booking is None:
        raise NotFound(f"booking {booking_id} not found")
    if booking.status == models.BookingStatus.PAID:
        raise Conflict("booking is already paid")
    if booking.status == models.BookingStatus.CANCELLED:
        raise Conflict("booking is cancelled")
    if _as_utc(booking.expires_at) < datetime.now(UTC):
        booking.status = models.BookingStatus.CANCELLED
        db.commit()
        raise Conflict("booking hold expired, please book again")

    payment = models.Payment(
        booking_id=booking.id,
        amount=booking.seat.event.price,
        method=data.method,
        idempotency_key=idempotency_key,
    )
    ticket = models.Ticket(booking_id=booking.id)
    booking.status = models.BookingStatus.PAID
    db.add_all([payment, ticket])
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise Conflict("booking is already paid") from None
    return ticket


def ticket_out(ticket: models.Ticket) -> schemas.TicketOut:
    b = ticket.booking
    return schemas.TicketOut(
        code=ticket.code,
        booking_id=b.id,
        issued_at=ticket.issued_at,
        event_title=b.seat.event.title,
        seat=f"{b.seat.row}{b.seat.number}",
        customer_name=b.customer_name,
        amount_paid=b.payment.amount,
    )


def get_ticket(db: Session, code: str) -> models.Ticket:
    ticket = db.scalar(select(models.Ticket).where(models.Ticket.code == code))
    if ticket is None:
        raise NotFound("ticket not found")
    return ticket
