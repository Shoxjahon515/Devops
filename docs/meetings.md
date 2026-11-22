# Planning and stand-up notes

Product Owner / Scrum Master role. Solo project: the "stand-up" is a short written plan.

## Week 4 — project start

- Topic chosen: ticket booking (ADR-001). Repository `Devops` created, `main` protected.
- Issues planned for Week 5:
  1. `app skeleton` — FastAPI app with `/health`, events and seats (label: enhancement)
  2. `Dockerfile` — multi-stage image, non-root user, healthcheck (label: devops)
  3. `README run steps` — clone → one command → running (label: documentation)

## Week 5 — containerisation

- Done: booking, payment and ticket endpoints; double-booking guard; idempotent payments; 14 tests.
- Done: Dockerfile, Docker Compose stack (API, PostgreSQL, nginx, cAdvisor), CI workflow.
- Next: deploy to the VM with `docker compose up -d`, then scaling and load test.

## Backlog (to week 14)

- Alembic migrations instead of `create_all`
- Push the image to GHCR from CI on every merge to `main`
- Kubernetes manifests (Deployment, Service, ConfigMap/Secret, probes)
- Load test of `POST /bookings` (k6 or locust) and a Grafana dashboard
