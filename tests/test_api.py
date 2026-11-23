PERSON = {"customer_name": "Shoxjahon Tuymurodov", "customer_email": "student@example.com"}


def book(client, seat_id, **extra):
    return client.post("/bookings", json={"seat_id": seat_id, **PERSON, **extra})


def test_health(client):
    r = client.get("/health")
    assert r.status_code == 200
    assert r.json()["status"] == "ok"


def test_create_event_generates_seats(client, event):
    assert event["total_seats"] == 6
    assert event["available_seats"] == 6
    seats = client.get(f"/events/{event['id']}/seats").json()
    assert [f"{s['row']}{s['number']}" for s in seats] == ["A1", "A2", "A3", "B1", "B2", "B3"]


def test_invalid_event_is_rejected(client):
    r = client.post(
        "/events",
        json={
            "title": "",
            "venue": "x",
            "starts_at": "2030-01-01T00:00:00Z",
            "price": "-1",
            "rows": 0,
            "seats_per_row": 1,
        },
    )
    assert r.status_code == 422


def test_booking_holds_the_seat(client, event, seat_id):
    r = book(client, seat_id)
    assert r.status_code == 201
    assert r.json()["status"] == "pending"
    assert client.get(f"/events/{event['id']}").json()["available_seats"] == 5
    free = client.get(f"/events/{event['id']}/seats?available=true").json()
    assert seat_id not in [s["id"] for s in free]


def test_same_seat_cannot_be_booked_twice(client, seat_id):
    assert book(client, seat_id).status_code == 201
    r = book(client, seat_id)
    assert r.status_code == 409
    assert "already booked" in r.json()["detail"]


def test_cancel_releases_the_seat(client, seat_id):
    booking = book(client, seat_id).json()
    r = client.post(f"/bookings/{booking['id']}/cancel")
    assert r.json()["status"] == "cancelled"
    assert book(client, seat_id).status_code == 201


def test_pay_issues_ticket(client, seat_id):
    booking = book(client, seat_id).json()
    r = client.post(
        f"/bookings/{booking['id']}/pay",
        json={"method": "card"},
        headers={"Idempotency-Key": "pay-key-0001"},
    )
    assert r.status_code == 201, r.text
    ticket = r.json()
    assert ticket["seat"] == "A1"
    assert ticket["amount_paid"] == "150000.00"
    assert client.get(f"/tickets/{ticket['code']}").json()["booking_id"] == booking["id"]
    assert client.get(f"/bookings/{booking['id']}").json()["status"] == "paid"


def test_payment_retry_with_same_key_does_not_charge_twice(client, seat_id):
    booking = book(client, seat_id).json()
    headers = {"Idempotency-Key": "retry-key-0001"}
    first = client.post(f"/bookings/{booking['id']}/pay", json={"method": "payme"}, headers=headers)
    again = client.post(f"/bookings/{booking['id']}/pay", json={"method": "payme"}, headers=headers)
    assert first.status_code == again.status_code == 201
    assert first.json()["code"] == again.json()["code"]


def test_second_payment_with_new_key_is_rejected(client, seat_id):
    booking = book(client, seat_id).json()
    url = f"/bookings/{booking['id']}/pay"
    client.post(url, json={"method": "card"}, headers={"Idempotency-Key": "key-aaaa-1"})
    r = client.post(url, json={"method": "card"}, headers={"Idempotency-Key": "key-bbbb-2"})
    assert r.status_code == 409


def test_paid_booking_cannot_be_cancelled(client, seat_id):
    booking = book(client, seat_id).json()
    client.post(
        f"/bookings/{booking['id']}/pay",
        json={"method": "cash"},
        headers={"Idempotency-Key": "cash-key-01"},
    )
    assert client.post(f"/bookings/{booking['id']}/cancel").status_code == 409


def test_payment_requires_idempotency_key(client, seat_id):
    booking = book(client, seat_id).json()
    r = client.post(f"/bookings/{booking['id']}/pay", json={"method": "card"})
    assert r.status_code == 422


def test_expired_hold_frees_the_seat(client, seat_id, monkeypatch):
    from app import services
    from app.config import Settings

    monkeypatch.setattr(
        services,
        "get_settings",
        lambda: Settings("sqlite://", booking_hold_minutes=-1, app_version="t"),
    )
    expired = book(client, seat_id).json()  # hold already in the past
    monkeypatch.undo()
    r = client.post(
        f"/bookings/{expired['id']}/pay",
        json={"method": "card"},
        headers={"Idempotency-Key": "late-key-01"},
    )
    assert r.status_code == 409
    assert book(client, seat_id).status_code == 201  # seat is free again


def test_unknown_ids_return_404(client):
    assert client.get("/events/999").status_code == 404
    assert client.get("/bookings/999").status_code == 404
    assert client.get("/tickets/nope").status_code == 404
    assert book(client, 999).status_code == 404


def test_list_events_counts(client, event, seat_id):
    book(client, seat_id)
    events = client.get("/events").json()
    assert events[0]["total_seats"] == 6
    assert events[0]["available_seats"] == 5


def test_ui_page_is_served(client):
    r = client.get("/ui")
    assert r.status_code == 200
    assert r.headers["content-type"].startswith("text/html")
    assert "PayFast Tickets" in r.text
