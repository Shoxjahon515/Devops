from datetime import datetime
from decimal import Decimal
from typing import Literal

from pydantic import BaseModel, ConfigDict, EmailStr, Field

from app.models import BookingStatus


class EventCreate(BaseModel):
    title: str = Field(min_length=1, max_length=200)
    venue: str = Field(min_length=1, max_length=200)
    starts_at: datetime
    price: Decimal = Field(ge=0, max_digits=12, decimal_places=2)
    rows: int = Field(ge=1, le=26, description="Rows A..Z")
    seats_per_row: int = Field(ge=1, le=50)


class EventOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    title: str
    venue: str
    starts_at: datetime
    price: Decimal
    total_seats: int
    available_seats: int


class SeatOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    row: str
    number: int
    available: bool


class BookingCreate(BaseModel):
    seat_id: int
    customer_name: str = Field(min_length=2, max_length=120)
    customer_email: EmailStr


class BookingOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    seat_id: int
    customer_name: str
    customer_email: str
    status: BookingStatus
    created_at: datetime
    expires_at: datetime


class PaymentCreate(BaseModel):
    method: Literal["card", "cash", "payme", "click"]


class TicketOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    code: str
    booking_id: int
    issued_at: datetime
    event_title: str
    seat: str
    customer_name: str
    amount_paid: Decimal
