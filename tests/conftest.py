import os

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

# Tests use an in-memory SQLite database unless TEST_DATABASE_URL points to PostgreSQL
os.environ.setdefault("DATABASE_URL", "sqlite://")

from app.database import Base, get_db  # noqa: E402
from app.main import app  # noqa: E402


@pytest.fixture()
def client():
    url = os.getenv("TEST_DATABASE_URL", "sqlite://")
    if url.startswith("sqlite"):
        engine = create_engine(url, connect_args={"check_same_thread": False}, poolclass=StaticPool)
    else:
        engine = create_engine(url)
    Base.metadata.drop_all(engine)
    Base.metadata.create_all(engine)
    TestSession = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)

    def override_get_db():
        db = TestSession()
        try:
            yield db
        finally:
            db.close()

    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as c:
        yield c
    app.dependency_overrides.clear()
    Base.metadata.drop_all(engine)
    engine.dispose()


@pytest.fixture()
def event(client):
    r = client.post(
        "/events",
        json={
            "title": "PDP Rock Night",
            "venue": "PDP Hall",
            "starts_at": "2030-05-01T19:00:00Z",
            "price": "150000.00",
            "rows": 2,
            "seats_per_row": 3,
        },
    )
    assert r.status_code == 201, r.text
    return r.json()


@pytest.fixture()
def seat_id(client, event):
    return client.get(f"/events/{event['id']}/seats").json()[0]["id"]
