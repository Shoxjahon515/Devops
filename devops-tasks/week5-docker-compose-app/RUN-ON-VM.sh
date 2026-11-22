#!/usr/bin/env bash
# RUN-ON-VM.sh - start the stack on your Ubuntu VM, run every check and save
# the output to ~/compose-evidence.txt for the submission.
# Usage (in this folder, on the VM):  bash RUN-ON-VM.sh
set -uo pipefail

OUT="$HOME/compose-evidence.txt"
: > "$OUT"
section() { printf '\n===== %s =====\n' "$*" | tee -a "$OUT"; }
run() { printf '$ %s\n' "$*" | tee -a "$OUT"; bash -c "$*" 2>&1 | tee -a "$OUT"; }

[[ -f .env ]] || { cp .env.example .env; echo "Created .env from .env.example (change DB_PASS later)."; }

# Host nginx/apache from earlier weeks would hold port 80
for svc in nginx apache2; do
    if systemctl is-active --quiet "$svc"; then
        echo "Stopping host $svc so the nginx container can use port 80"
        sudo systemctl stop "$svc"
    fi
done

section "Build and start"
run "docker compose up --build -d"
echo "Waiting for healthchecks..."
for _ in $(seq 1 30); do
    docker compose ps --format '{{.Service}} {{.Health}}' | grep -qvE ' healthy$' || break
    sleep 3
done
section "docker compose ps"
run "docker compose ps"

section "API checks"
run "curl -s http://localhost/health; echo"
run "curl -s http://localhost/; echo"
run "curl -s -X POST http://localhost/notes -H 'Content-Type: application/json' -d '{\"text\":\"Hello from Docker Compose\"}'; echo"
run "curl -s -o /dev/null -w 'empty note -> HTTP %{http_code}\n' -X POST http://localhost/notes -H 'Content-Type: application/json' -d '{\"text\":\"\"}'"
run "curl -s http://localhost/notes; echo"

section "Scale to 3 app replicas (load balancing)"
run "docker compose up -d --scale app=3"
sleep 15
run "for i in 1 2 3 4 5 6; do curl -s http://localhost/; echo; done"

section "Persistence: down / up keeps the data"
run "docker compose down"
run "docker compose up -d"
sleep 20
run "curl -s http://localhost/notes; echo"

section "Monitoring"
run "curl -s -o /dev/null -w 'cAdvisor -> HTTP %{http_code}\n' http://127.0.0.1:8080/containers/"
run "docker stats --no-stream"

echo
echo "Saved to $OUT"
echo "Screenshots to take: 'docker compose ps' (all healthy), the browser at http://<VM-IP>/,"
echo "the scale test output, and cAdvisor (ssh -p 2222 -L 8080:127.0.0.1:8080 <user>@<VM-IP>, then http://localhost:8080)."
