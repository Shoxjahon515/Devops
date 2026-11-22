#!/usr/bin/env bash
# Practical B3-B6: move SSH to 2222, keys only, no root login, then ufw.
# Two steps on purpose, so you test the new login BEFORE the firewall closes 22:
#   bash harden-ssh.sh          # step 1: firewall rules (not enabled) + SSH hardening
#   (open a NEW PuTTY session on port 2222 with your key - it must work)
#   bash harden-ssh.sh enable   # step 2: enable ufw and save the evidence
# Rollback from the VirtualBox console:
#   sudo rm /etc/ssh/sshd_config.d/01-hardening.conf && sudo systemctl restart ssh && sudo ufw disable
set -euo pipefail

OUT="$HOME/week2-evidence.txt"
section() { printf '\n===== %s =====\n' "$*" | tee -a "$OUT"; }
run() { printf '$ %s\n' "$*" | tee -a "$OUT"; bash -c "$*" 2>&1 | tee -a "$OUT"; }

if [[ "${1:-}" == "enable" ]]; then
    section "B6 Enable the firewall"
    run "sudo ufw --force enable"
    run "sudo ufw status numbered"
    run "sudo sshd -T | grep -Ei '^(port|passwordauthentication|permitrootlogin) '"
    cat <<'EOF'

From Windows PowerShell (screenshot these):
  curl.exe -I http://<VM-IP>                 -> HTTP/1.1 200 OK
  Test-NetConnection <VM-IP> -Port 2222      -> TcpTestSucceeded : True
  Test-NetConnection <VM-IP> -Port 22        -> TcpTestSucceeded : False
And a PuTTY session WITHOUT a key on port 2222 -> "No supported authentication methods" (screenshot).
EOF
    exit 0
fi

# --- safety check: refuse to disable passwords if no key is installed ---
if [[ ! -s "$HOME/.ssh/authorized_keys" ]]; then
    echo "STOP: ~/.ssh/authorized_keys is empty. Set up key login with PuTTYgen first (Week 1)."
    exit 1
fi

section "B3 Prepare firewall rules (ufw stays inactive)"
run "sudo ufw status verbose"
run "sudo ufw default deny incoming"
run "sudo ufw default allow outgoing"
run "sudo ufw allow 2222/tcp comment 'SSH'"
run "sudo ufw allow 80/tcp comment 'HTTP'"
run "sudo ufw show added"

section "B4-B5 Harden SSH"
run "sudo cp -n /etc/ssh/sshd_config /etc/ssh/sshd_config.bak"
sudo tee /etc/ssh/sshd_config.d/01-hardening.conf >/dev/null <<'EOF'
Port 2222
PasswordAuthentication no
PermitRootLogin no
PermitEmptyPasswords no
MaxAuthTries 3
LoginGraceTime 30
X11Forwarding no
EOF
run "cat /etc/ssh/sshd_config.d/01-hardening.conf"
run "sudo sshd -t && echo 'sshd -t: syntax OK'"
# Ubuntu 24.04+ may start ssh via socket activation, which ignores Port in sshd_config
if systemctl is-enabled --quiet ssh.socket 2>/dev/null; then
    run "sudo systemctl disable --now ssh.socket && sudo systemctl enable ssh"
fi
run "sudo systemctl restart ssh"
run "sudo ss -tlnp | grep sshd"

cat <<'EOF'

DO NOT close this PuTTY window.
Open a NEW PuTTY session: same host, Port 2222, same .ppk key.
If it works:   bash harden-ssh.sh enable
If it fails:   fix it from this window (see rollback line at the top of this file).
EOF
