# Changelog

All notable changes are documented here. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versions: [SemVer](https://semver.org/).

## [1.0.0] — 2026-11-22

### Added
- Events with generated seat maps (rows A–Z × seats per row).
- Seat holds (`pending` bookings) that expire after `BOOKING_HOLD_MINUTES`.
- Double-booking guard enforced by a partial unique index in the database.
- Idempotent payments (`Idempotency-Key` header) with row locking; ticket issued on payment.
- Ticket lookup by code; booking cancellation.
- Health endpoint with database check (`503` when the database is unreachable).
- Multi-stage Dockerfile (non-root, healthcheck), Docker Compose stack with PostgreSQL 16, nginx 1.27 (load balancing, rate limiting) and cAdvisor.
- GitHub Actions CI: ruff, pytest on SQLite and PostgreSQL, Docker build and smoke test.
- Documentation: README, architecture decisions, access register, contributing and security policy.
- DevOps course tasks for weeks 1–5 in `devops-tasks/`.
