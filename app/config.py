"""Settings come from environment variables (12-factor): the same image runs in
dev, CI and production with different configuration and no code change."""

import os
from dataclasses import dataclass


@dataclass(frozen=True)
class Settings:
    database_url: str
    booking_hold_minutes: int
    app_version: str


def get_settings() -> Settings:
    return Settings(
        database_url=os.getenv("DATABASE_URL", "sqlite:///./payfast.db"),
        booking_hold_minutes=int(os.getenv("BOOKING_HOLD_MINUTES", "15")),
        app_version=os.getenv("APP_VERSION", "1.1.0"),
    )
