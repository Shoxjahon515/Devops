# Week 5 — Containerisation with Docker (Task 5)

`payfast-hello/` is the sample app from Practical B: Flask with `/` and `/health`, served by gunicorn.

## Build, run, cache (B2–B5)

```bash
cd payfast-hello
docker build -t payfast-hello:1.0.0 .
docker run -d --name hello -p 8080:8000 payfast-hello:1.0.0
curl localhost:8080            # {"host":"<container id>","service":"payfast-hello","version":"1.0.0"}
curl localhost:8080/health     # {"status":"ok"}
docker history payfast-hello:1.0.0

# B4 build cache: change the default version in app.py to 1.1.0, then
docker build -t payfast-hello:1.1.0 .
# -> WORKDIR, COPY requirements.txt and RUN pip are CACHED, only COPY app.py runs

# B5 one image, many containers - configuration from the environment
docker rm -f hello
docker run -d --name a -p 8080:8000 payfast-hello:1.1.0
docker run -d --name b -p 8081:8000 -e APP_VERSION=2.0.0 payfast-hello:1.1.0
curl localhost:8080; curl localhost:8081      # 1.1.0 vs 2.0.0, different hosts
docker rm -f a b
```

## Push to GHCR (B6)

```bash
nano ~/.config/ghcr-token && chmod 600 ~/.config/ghcr-token     # classic token, write:packages
docker login ghcr.io -u <github-username> --password-stdin < ~/.config/ghcr-token
for v in 1.0.0 1.1.0; do
  docker tag payfast-hello:$v ghcr.io/<github-username>/payfast-hello:$v
  docker push ghcr.io/<github-username>/payfast-hello:$v
done
docker logout ghcr.io
```

Then on GitHub: Packages → payfast-hello → Package settings → Change visibility → Public.

## Exit questions

1. **Image vs container?** An image is a read-only template (layers of files + metadata). A container is a running (or stopped) instance of an image with its own writable layer, process, network and name. One image → many containers.
2. **Why copy `requirements.txt` before `app.py`?** Docker caches each layer; a layer is rebuilt only if its input changed. Dependencies change rarely, code often — with this order a code edit reuses the slow `pip install` layer.
3. **Why must gunicorn listen on `0.0.0.0` inside the container?** `127.0.0.1` inside the container is the container's own loopback; Docker's port forwarding arrives on the container's network interface, so a server bound to 127.0.0.1 would refuse it (empty reply / connection reset).
4. **Why `--password-stdin` with a token file?** A password on the command line is saved in shell history and visible in `ps`; a 600 token file is readable only by me, and a token can be limited in scope and revoked without changing my GitHub password.

The full team-style application (FastAPI + PostgreSQL + Nginx) with its multi-stage `Dockerfile` is in the root of this repository — that is the B8 "team Dockerfile".
