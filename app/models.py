import enum
import uuid
from datetime import UTC, datetime
from decimal import Decimal

from sqlalchemy import (
    CheckConstraint,
    DateTime,
    Enum,
    ForeignKey,
    Index,
    Integer,
    Numeric,
    String,
    UniqueConstraint,
    text,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


def utcnow() -> datetime:
    return datetime.now(UTC)


class BookingStatus(enum.StrEnum):
    PENDING = "pending"  # seat is held, waiting for payment
    PAID = "paid"  # paid, ticket issued
    CANCELLED = "cancelled"  # seat released


class Event(Base):
    __tablename__ = "events"

    id: Mapped[int] = mapped_column(primary_key=True)
    title: Mapped[str] = mapped_column(String(200))
    venue: Mapped[str] = mapped_column(String(200))
    starts_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    price: Mapped[Decimal] = mapped_column(Numeric(12, 2))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)

    seats: Mapped[list["Seat"]] = relationship(
        back_populates="event", cascade="all, delete-orphan", order_by="Seat.id"
    )

    __table_args__ = (CheckConstraint("price >= 0", name="ck_event_price_non_negative"),)


class Seat(Base):
    __tablename__ = "seats"

    id: Mapped[int] = mapped_column(primary_key=True)
    event_id: Mapped[int] = mapped_column(ForeignKey("events.id", ondelete="CASCADE"), index=True)
    row: Mapped[str] = mapped_column(String(5))
    number: Mapped[int] = mapped_column(Integer)

    event: Mapped[Event] = relationship(back_populates="seats")

    __table_args__ = (UniqueConstraint("event_id", "row", "number", name="uq_seat_position"),)


class Booking(Base):
    __tablename__ = "bookings"

    id: Mapped[int] = mapped_column(primary_key=True)
    seat_id: Mapped[int] = mapped_column(ForeignKey("seats.id"), index=True)
    customer_name: Mapped[str] = mapped_column(String(120))
    customer_email: Mapped[str] = mapped_column(String(254))
    status: Mapped[BookingStatus] = mapped_column(
        Enum(BookingStatus, native_enum=False, length=20), default=BookingStatus.PENDING
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))

    seat: Mapped[Seat] = relationship()
    payment: Mapped["Payment | None"] = relationship(back_populates="booking")
    ticket: Mapped["Ticket | None"] = relationship(back_populates="booking")

    __table_args__ = (
        # THE double-booking guard: at most one non-cancelled booking per seat.
        # Enforced by the database, so it also holds when two API replicas
        # receive requests for the same seat at the same moment.
        Index(
            "uq_active_booking_per_seat",
            "seat_id",
            unique=True,
            postgresql_where=text("status <> 'CANCELLED'"),
            sqlite_where=text("status <> 'CANCELLED'"),
        ),
    )


class Payment(Base):
    __tablename__ = "payments"

    id: Mapped[int] = mapped_column(primary_key=True)
    booking_id: Mapped[int] = mapped_column(ForeignKey("bookings.id"), unique=True)
    amount: Mapped[Decimal] = mapped_column(Numeric(12, 2))
    method: Mapped[str] = mapped_column(String(20))
    # The same Idempotency-Key sent twice (client retry) must not charge twice
    idempotency_key: Mapped[str] = mapped_column(String(100), unique=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)

    booking: Mapped[Booking] = relationship(back_populates="payment")


class Ticket(Base):
    __tablename__ = "tickets"

    id: Mapped[int] = mapped_column(primary_key=True)
    booking_id: Mapped[int] = mapped_column(ForeignKey("bookings.id"), unique=True)
    code: Mapped[str] = mapped_column(String(36), unique=True, default=lambda: str(uuid.uuid4()))
    issued_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)

    booking: Mapped[Booking] = relationship(back_populates="ticket")
