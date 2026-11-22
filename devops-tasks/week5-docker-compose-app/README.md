# Notes stack — a full working app with Docker Compose

Unit 4 DevOps · Week 5–6 · "Creating a full working app with Docker compose"
Based on Docker HomeLab EP10 (Flask + Postgres + Nginx + cAdvisor), extended to production practices.
Author: Shoxjahon Tuymurodov, group 23-309

## Architecture

```
            laptop browser
                  │  :80
        ┌─────────▼─────────┐            frontend network
        │  nginx (reverse   │──────────────────────────────┐
        │  proxy + LB)      │                              │
        └─────────┬─────────┘                    ┌─────────▼────────┐
                  │ round-robin :5000            │ cAdvisor :8080   │
     ┌────────────┼────────────┐                 │ (127.0.0.1 only) │
 ┌───▼───┐    ┌───▼───┐    ┌───▼───┐             └──────────────────┘
 │ app#1 │    │ app#2 │    │ app#3 │   Flask + gunicorn, non-root
 └───┬───┘    └───┬───┘    └───┬───┘
     └────────────┼────────────┘          backend network (internal: no internet)
            ┌─────▼─────┐
            │ Postgres  │── volume dbdata (data survives restarts)
            └───────────┘
```

| Service | Image | Role | Published |
|---|---|---|---|
| `nginx` | `nginx:1.27-alpine` | single entry point, reverse proxy, load balancer | `80:80` |
| `app` | built from `./app` | Flask API run by gunicorn (2 workers), scalable | internal `5000` only |
| `db` | `postgres:16-alpine` | database, named volume `dbdata` | not published |
| `cadvisor` | `gcr.io/cadvisor/cadvisor:v0.49.1` | container CPU/RAM/network metrics | `127.0.0.1:8080` |

## API

| Method | Path | Result |
|---|---|---|
| GET | `/` | service, version, **which container answered** (`host`), total visits stored in Postgres |
| GET | `/health` | `200 {"status":"ok"}` or `503` when the DB is unreachable |
| GET | `/notes` | list notes |
| POST | `/notes` | `{"text":"..."}` → `201`; empty or >500 chars → `400` |

## Run it

```bash
cp .env.example .env          # then edit DB_PASS
docker compose up --build -d
docker compose ps             # all services "healthy"
curl http://localhost/
curl -X POST http://localhost/notes -H 'Content-Type: application/json' -d '{"text":"hello"}'
curl http://localhost/notes
```

Open `http://<VM-IP>/` from the laptop. cAdvisor: on the VM `curl -I http://127.0.0.1:8080`, or from the laptop through an SSH tunnel: `ssh -p 2222 -L 8080:127.0.0.1:8080 student@<VM-IP>` then `http://localhost:8080`.

## Scale the app (load balancing)

```bash
docker compose up -d --scale app=3
for i in 1 2 3 4 5 6; do curl -s http://localhost/ ; echo; done
```

The `host` value changes between three container IDs: nginx spreads requests round-robin. `nginx.conf` uses Docker's DNS (`resolver 127.0.0.11` + `server app:5000 resolve`), so new replicas are found without restarting nginx.

## Prove the data persists

```bash
curl -X POST http://localhost/notes -H 'Content-Type: application/json' -d '{"text":"survives"}'
docker compose down           # removes containers, KEEPS the dbdata volume
docker compose up -d
curl http://localhost/notes   # the note is still there
# docker compose down -v      # -v would delete the volume and the data
```

## Production practices used (vs. the original EP10)

| Original EP10 | This version | Why |
|---|---|---|
| `python app.py` (Flask dev server) | `gunicorn` with 2 workers | the dev server is single-threaded and not meant for production |
| new DB connection per request | connection pool, broken connections are discarded | fewer connections; app recovers by itself after a Postgres restart |
| `depends_on` start order only | healthchecks + `condition: service_healthy` | the app starts only when Postgres really accepts connections |
| one network | `frontend` + `backend` (`internal: true`) | the database is not reachable from outside and has no internet access |
| `.env` with real values in Git | `.env.example` in Git, `.env` in `.gitignore` | no credentials in the repository |
| `COPY . .` before nothing | `requirements.txt` copied before code | code edits reuse the pip layer from the build cache |
| `latest` image tags | pinned tags (`postgres:16-alpine`, `nginx:1.27-alpine`, cAdvisor `v0.49.1`) | repeatable builds |
| cAdvisor on `0.0.0.0:8080` | `127.0.0.1:8080` | Docker-published ports bypass ufw (Week 5, A7) |
| no limits | `cpus: 0.5`, `memory: 256M` on app | one replica cannot starve the VM |
| only `/` | `/health`, `/notes` CRUD with validation (400 on bad input) | a real working app, health endpoint for Docker and monitoring |
| no schema | tables created at start, guarded with an advisory lock | several replicas starting together cannot collide |

## Useful commands

```bash
docker compose logs -f app nginx      # live logs (gunicorn + nginx access log with upstream address)
docker compose exec db psql -U "$DB_USER" -d "$DB_NAME" -c 'select count(*) from visits;'
docker stats --no-stream
docker compose down                    # stop; add -v to also delete data
```

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `app` stays `starting` / `unhealthy` | `docker compose logs app`; usually wrong values in `.env` |
| `502 Bad Gateway` | app containers not ready yet, or crashed: `docker compose ps` |
| `port is already allocated` on 80 | host nginx/apache uses port 80: `sudo systemctl stop nginx apache2` |
| `set DB_USER in .env` error | you did not create `.env` from `.env.example` |

## Testing done

- `docker compose config --quiet` — the compose file is valid.
- The app was run with gunicorn against PostgreSQL 16 behind nginx with three app instances: `/`, `/health`, `/notes` (GET/POST, 400 on empty text) all correct; 300 concurrent requests (`ab -c 20/30`) with 0 failures.
- Postgres was stopped: `/health` returned `503` (not a crash); after Postgres restarted the app recovered without a restart.
- `ruff check app.py` — no issues.
