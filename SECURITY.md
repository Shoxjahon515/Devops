# Security policy

## Reporting a vulnerability

Please do **not** open a public issue. Contact the maintainer, Shoxjahon Tuymurodov, through GitHub (private message or a private security advisory on this repository). You will get an answer within 3 working days.

## What is in place

| Area | Control |
|---|---|
| Secrets | configuration from environment variables; `.env` is git-ignored; only `.env.example` with placeholders is committed |
| Container | non-root user (UID 10001), multi-stage build without compilers, pinned base image |
| Network | only nginx is published; PostgreSQL is on an `internal` Docker network; cAdvisor bound to `127.0.0.1` |
| HTTP | nginx rate limit on `/bookings`, request body limit 1 MB, `server_tokens off` |
| Data integrity | unique constraints and row locks against double booking and double payment; idempotent payments |
| Input | Pydantic validation (types, lengths, e-mail format, enum of payment methods) |
| SQL injection | SQLAlchemy ORM with bound parameters only, no string-built SQL |
| Supply chain | pinned dependency versions; Dependabot for pip, Docker and GitHub Actions |
| Review | protected `main`, pull requests with CI checks |

## Known limitations (course project)

- No authentication yet: anyone who can reach the API can create events. Planned: JWT for organisers.
- Payments are simulated; no real payment provider is called.
- HTTPS is terminated outside this stack (to be added with a reverse proxy certificate).
