<div align="center">

# 🎫 PayFast Tickets

**Event ticket booking API — Unit 4 DevOps course project**

**English** · [O'zbekcha](README.uz.md)

[![CI](https://github.com/Shoxjahon515/Devops/actions/workflows/ci.yml/badge.svg)](https://github.com/Shoxjahon515/Devops/actions/workflows/ci.yml)
![Python](https://img.shields.io/badge/Python-3.12-3776AB?logo=python&logoColor=white)
![FastAPI](https://img.shields.io/badge/FastAPI-0.115-009688?logo=fastapi&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-4169E1?logo=postgresql&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker&logoColor=white)
![Nginx](https://img.shields.io/badge/Nginx-1.27-009639?logo=nginx&logoColor=white)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

</div>

| | |
|---|---|
| **Author** | Shoxjahon Tuymurodov · group 23-309 · PDP University |
| **Course** | Unit 4 — DevOps (Pearson BTEC Level 6, Unit 70728U) |
| **Teacher** | Muhammadjon Xolmirzayev (`@MuhammadjonX`) |
| **Topic** | 1 — Ticket booking (event, seat, booking, payment, ticket) |
| **Version** | 1.0.0 — see [CHANGELOG](CHANGELOG.md) |

A REST API to sell tickets for events: create an event with a seat map, hold a seat, pay for it exactly once (even if the client retries) and receive a ticket. **Two people can never get the same seat**, even when the API runs as several replicas behind nginx — this is guaranteed by the database and verified under parallel load.

### Highlights

- ✅ Double booking impossible — partial unique index, tested with 50 parallel requests on 2 replicas
- ✅ Idempotent, row-locked payments — retries never charge twice
- ✅ One-command start: `make up` (or `docker compose up --build -d`)
- ✅ Production-style container: multi-stage, non-root, healthchecks, gunicorn + uvicorn workers
- ✅ nginx reverse proxy with load balancing and rate limiting; database on an internal network
- ✅ CI on every push: lint, tests on SQLite **and** PostgreSQL, Docker build + smoke test
- ✅ All weekly DevOps course tasks in [`devops-tasks/`](devops-tasks/)

---

## Contents

1. [Team and roles](#1-team-and-roles)
2. [Quick start (Docker)](#2-quick-start-docker)
3. [API](#3-api)
4. [Architecture](#4-architecture)
5. [Local development and tests](#5-local-development-and-tests)
6. [CI](#6-ci)
7. [Operations](#7-operations)
8. [Repository layout](#8-repository-layout)
9. [Team agreement](#9-team-agreement)
10. [Project documents](#10-project-documents)
11. [DevOps course tasks](#11-devops-course-tasks)

---

## 1. Team and roles

Solo project: I was not placed in a team, so I hold all five roles from the course's role list.

| Role | Responsibilities in this repo | Evidence |
|---|---|---|
| Tech Lead | repository, protected `main`, final merges, teacher access | branch rule, `docs/access.md` |
| Product Owner / Scrum Master | issues, labels, plan | GitHub Issues, `docs/meetings.md` |
| QA & Code Review Lead | PR template, review checklist, tests | `.github/pull_request_template.md`, `tests/` |
| DevOps / Platform Engineer | Dockerfile, Compose, nginx, CI | `Dockerfile`, `docker-compose.yml`, `.github/workflows/ci.yml` |
| Technical Writer & Security Champion | README, access register, decisions, secret checks | this file, `docs/access.md`, `docs/decisions.md` |

## 2. Quick start (Docker)

Requirements: Docker Engine with the Compose plugin (`docker compose version`).

> Shortcut: `make up` does the copy of `.env` and the build in one step. `make help` lists every command.

```bash
git clone https://github.com/Shoxjahon515/Devops.git
cd Devops
cp .env.example .env              # change POSTGRES_PASSWORD (letters and digits)
docker compose up --build -d
docker compose ps                 # db, api, nginx -> healthy
curl http://localhost/health      # {"status":"ok","db":"ok",...}
```

Open **http://localhost/docs** (or `http://<VM-IP>/docs`) for the interactive Swagger UI.

> Port 80 busy? Stop the host web servers from earlier weeks: `sudo systemctl stop nginx apache2`.

### Try the whole flow

```bash
# 1. an event with 2 rows x 5 seats
curl -s -X POST http://localhost/events -H 'Content-Type: application/json' -d '{
  "title":"PDP Rock Night","venue":"PDP Hall","starts_at":"2030-05-01T19:00:00Z",
  "price":"150000","rows":2,"seats_per_row":5}'

# 2. free seats
curl -s "http://localhost/events/1/seats?available=true"

# 3. hold seat 1 (15 minutes)
curl -s -X POST http://localhost/bookings -H 'Content-Type: application/json' \
  -d '{"seat_id":1,"customer_name":"Shoxjahon Tuymurodov","customer_email":"me@example.com"}'

# 4. the same seat again -> 409 Conflict
curl -s -X POST http://localhost/bookings -H 'Content-Type: application/json' \
  -d '{"seat_id":1,"customer_name":"Someone Else","customer_email":"x@example.com"}'

# 5. pay (safe to retry with the same key) -> ticket
curl -s -X POST http://localhost/bookings/1/pay -H 'Content-Type: application/json' \
  -H 'Idempotency-Key: order-0001-attempt' -d '{"method":"card"}'

# 6. check the ticket
curl -s http://localhost/tickets/<code-from-step-5>
```

### Scale and persistence

```bash
docker compose up -d --scale api=3
for i in 1 2 3 4 5 6; do curl -s http://localhost/; echo; done   # "host" changes: round-robin
docker compose down && docker compose up -d                      # data kept in volume pgdata
docker compose down -v                                           # also deletes the data
```

Monitoring: cAdvisor listens on `127.0.0.1:8080` of the VM. From the laptop: `ssh -p 2222 -L 8080:127.0.0.1:8080 <user>@<VM-IP>` → http://localhost:8080.

## 3. API

| Method | Path | Description | Success | Errors |
|---|---|---|---|---|
| GET | `/health` | liveness + database check | 200 | 503 DB unreachable |
| GET | `/` | version and the container that answered | 200 | |
| POST | `/events` | create event + seats (rows A–Z × seats per row) | 201 | 422 invalid |
| GET | `/events?limit=&offset=` | list events with free-seat counts | 200 | |
| GET | `/events/{id}` | one event | 200 | 404 |
| GET | `/events/{id}/seats?available=true` | seat map | 200 | 404 |
| POST | `/bookings` | hold a seat | 201 | 404 seat, 409 taken / event started, 422 |
| GET | `/bookings/{id}` | booking status (`pending`, `paid`, `cancelled`) | 200 | 404 |
| POST | `/bookings/{id}/cancel` | release the seat | 200 | 409 already paid |
| POST | `/bookings/{id}/pay` | pay; header `Idempotency-Key` (8–100 chars) | 201 ticket | 409 paid / cancelled / expired, 422 no key |
| GET | `/tickets/{code}` | ticket details | 200 | 404 |

Full schema: `/docs` (Swagger) and `/openapi.json`.

### Business rules

- **No double booking.** A partial unique index allows only one non-cancelled booking per seat. The database enforces it, so it holds across replicas (ADR-003).
- **Holds expire.** An unpaid booking keeps the seat for `BOOKING_HOLD_MINUTES` (default 15), then the seat is free again (ADR-005).
- **Pay once.** A retry with the same `Idempotency-Key` returns the same ticket. A second payment with a new key gets `409`. The booking row is locked during payment (ADR-004).
- **Validation.** Price ≥ 0, valid e-mail, payment method `card | cash | payme | click`. Bookings for events that have already started are refused.

## 4. Architecture

```
 client ──► nginx :80 ── rate limit on /bookings (10 r/s, burst 20) ──► api (×N, gunicorn + uvicorn workers)
                                                                          │  SQLAlchemy pool, pre_ping
                                                                          ▼
                                                    PostgreSQL 16  (network "backend", internal: true)
                                                    volume pgdata
 cAdvisor 127.0.0.1:8080 ── container CPU / RAM / network
```

| Layer | Choice | Why |
|---|---|---|
| API | FastAPI, Pydantic v2 | typed validation, automatic OpenAPI docs |
| Data | SQLAlchemy 2, PostgreSQL 16 | constraints and row locks protect money and seats |
| Server | gunicorn + uvicorn workers | restarts crashed workers, uses several cores |
| Proxy | nginx 1.27 | single entry point, load balancing, rate limiting, hides `server_tokens` |
| Image | multi-stage, `python:3.12-slim`, non-root user, healthcheck | small image, no build tools, least privilege |
| Network | `frontend` + `backend` (internal) | the database is unreachable from outside |

Design decisions with their reasons: [`docs/decisions.md`](docs/decisions.md).

## 5. Local development and tests

```bash
python3.12 -m venv .venv && source .venv/bin/activate
pip install -r requirements-dev.txt
uvicorn app.main:app --reload            # SQLite file payfast.db, http://127.0.0.1:8000/docs
ruff check . && ruff format --check .
pytest -q                                # 14 tests, in-memory SQLite
TEST_DATABASE_URL=postgresql+psycopg2://payfast:<password>@localhost:5432/payfast_test pytest -q
```

The tests cover seat generation, validation, holds, double booking, cancellation, payment, idempotent retries, a second payment, paid-cannot-cancel, expiry and 404s.

### Verified results

| Check | Result |
|---|---|
| `pytest` on SQLite and on PostgreSQL 16 | 14 / 14 passed on both |
| 50 parallel `POST /bookings` for **one seat** across **2 replicas** | exactly 1 × `201`, 49 × `409`, one row in the database |
| 20 parallel payments for one booking with different keys | 1 × `201`, 19 × `409`, 1 payment, 1 ticket |
| nginx in front of 2 replicas | requests alternate between replicas (round-robin) |
| burst of 60 booking requests through nginx | rate limit answered `429` to the excess |
| `ruff check .` · `docker compose config` | clean · valid |

## 6. CI

`.github/workflows/ci.yml` runs on every push to `main` and on every pull request:

1. **test** — `ruff check`, `pytest` on SQLite, `pytest` on a PostgreSQL 16 service container
2. **docker** — validates `docker-compose.yml`, builds the image, starts `db` + `api` and waits for the healthcheck

A red CI blocks the merge once "Require status checks" is enabled in the branch rule.

## 7. Operations

| Task | Command |
|---|---|
| Logs | `docker compose logs -f api nginx` |
| Database shell | `docker compose exec db psql -U payfast -d payfast` |
| Backup | `docker compose exec -T db pg_dump -U payfast payfast \| gzip > backup-$(date +%F).sql.gz` |
| Restore | `gunzip -c backup.sql.gz \| docker compose exec -T db psql -U payfast -d payfast` |
| Resource use | `docker stats --no-stream` or cAdvisor |
| Update | `git pull && docker compose up --build -d` |

| Symptom | Fix |
|---|---|
| `copy .env.example to .env` error | `cp .env.example .env` |
| `api` stays unhealthy | `docker compose logs api` — usually a wrong password in `.env` |
| `502 Bad Gateway` | API not ready or crashed: `docker compose ps` |
| `429 Too Many Requests` | rate limit on `/bookings`, retry later |

## 8. Repository layout

```
app/                  FastAPI application
  main.py             routes and error handlers
  services.py         business rules (booking, payment, expiry)
  models.py           SQLAlchemy models and constraints
  schemas.py          request/response models
  database.py config.py
tests/                pytest suite
nginx/                reverse proxy configuration
docs/                 access register, decisions, planning notes
.github/              CI workflow, Dependabot, PR and issue templates
devops-tasks/         weekly DevOps course tasks (weeks 1-5)
Dockerfile  docker-compose.yml  Makefile  .env.example  requirements*.txt  pyproject.toml
LICENSE  CHANGELOG.md  CONTRIBUTING.md  SECURITY.md
```

## 9. Team agreement

- **GitHub Flow:** `main` is always deployable. Work happens on a branch per issue (`feature/…`, `fix/…`, `docs/…`).
- **Pull requests:** every change goes through a PR using the template; CI must be green; `Closes #<issue>` in the description.
- **Review:** within 24 hours. In a solo project the teacher or a classmate is asked for review.
- **Commits:** imperative, clear messages ("Add booking expiry", not "fix").
- **Security:** no secrets in Git; `.env` stays local; see [`docs/access.md`](docs/access.md).

## 10. Project documents

| Document | Purpose |
|---|---|
| [README.uz.md](README.uz.md) | this README in Uzbek |
| [CHANGELOG.md](CHANGELOG.md) | what changed in each version |
| [CONTRIBUTING.md](CONTRIBUTING.md) | branch, commit and PR rules |
| [SECURITY.md](SECURITY.md) | how to report a vulnerability, security controls in place |
| [docs/decisions.md](docs/decisions.md) | architecture decision records (ADR-001 … ADR-007) |
| [docs/access.md](docs/access.md) | who has access and why |
| [docs/meetings.md](docs/meetings.md) | plan and backlog |
| [LICENSE](LICENSE) | MIT |

## 11. DevOps course tasks

All weekly tasks (SSH and Apache, Linux administration and the logs report, Bash and cron backups, Git, Docker, Docker Compose) are in **[`devops-tasks/`](devops-tasks/)**, one folder per week, each with its own README.

---

© 2026 Shoxjahon Tuymurodov · PDP University · educational project
