#!/usr/bin/env bash
# Week 1 - SSH, PuTTY and Apache2. Run on the Ubuntu VM (logged in through PuTTY):
#   bash RUN-ON-VM.sh "Shoxjahon Tuymurodov"
# Installs/checks openssh-server and apache2, publishes your own page and
# saves every command with its output to ~/week1-evidence.txt.
set -uo pipefail

NAME="${1:-Shoxjahon Tuymurodov}"
OUT="$HOME/week1-evidence.txt"
: > "$OUT"
section() { printf '\n===== %s =====\n' "$*" | tee -a "$OUT"; }
run() { printf '$ %s\n' "$*" | tee -a "$OUT"; bash -c "$*" 2>&1 | tee -a "$OUT"; }

section "Practical A - SSH server"
run "sudo apt update -qq"
run "sudo apt install -y -qq openssh-server"
run "sudo systemctl enable --now ssh"
run "systemctl is-active ssh; systemctl is-enabled ssh"
run "ip -br addr"
run "whoami; hostname; uname -a"
run "ls -ld ~/.ssh; ls -l ~/.ssh/authorized_keys 2>/dev/null || echo 'authorized_keys not created yet'"
run "sudo grep -E 'Accepted (publickey|password)' /var/log/auth.log | tail -3"

section "Practical B - navigation, files, permissions"
run "pwd; ls -la ~ | head"
run "mkdir -p ~/week1 && cd ~/week1 && echo 'my first file' > notes.txt && chmod 640 notes.txt && ls -l"
run "cat ~/week1/notes.txt"

section "Apache2 - install and test"
run "sudo apt install -y -qq apache2"
run "systemctl is-active apache2; systemctl is-enabled apache2"
run "cat <<EOF | sudo tee /var/www/html/index.html >/dev/null
<!doctype html><html><head><meta charset=utf-8><title>Week 1</title></head>
<body><h1>Hello from $NAME</h1><p>Group 23-309 · served by Apache2 on \$(hostname)</p></body></html>
EOF"
run "curl -s http://localhost"
run "curl -sI http://localhost | head -3"
run "sudo tail -n 5 /var/log/apache2/access.log"

IP=$(hostname -I | awk '{print $1}')
cat <<EOF

Saved to $OUT
Screenshots to take for the submission:
 1. PuTTY session window logged in (whoami / hostname visible)
 2. PuTTY: Connection > SSH > Auth > Credentials with your .ppk selected (never upload the .ppk itself)
 3. Windows browser at  http://$IP  showing "Hello from $NAME"
 4. Then on the VM:  sudo tail -n 3 /var/log/apache2/access.log  - your Windows visit appears
EOF
