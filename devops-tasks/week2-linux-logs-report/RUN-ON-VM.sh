#!/usr/bin/env bash
# Week 2 - Practical A (Linux administration) + read-only part of Practical B.
# Run on the VM:  bash RUN-ON-VM.sh
# Everything is saved to ~/week2-evidence.txt (this is also your command log).
# SSH hardening and the firewall are NOT done here - use harden-ssh.sh, it
# has safety checks so you cannot lock yourself out.
set -uo pipefail

OUT="$HOME/week2-evidence.txt"
: > "$OUT"
section() { printf '\n===== %s =====\n' "$*" | tee -a "$OUT"; }
why() { printf '# why: %s\n' "$*" | tee -a "$OUT"; }
run() { printf '$ %s\n' "$*" | tee -a "$OUT"; bash -c "$*" 2>&1 | tee -a "$OUT"; }

section "A1 Users and groups"
why "separate accounts per person; a group gives shared access without sharing passwords"
for u in alice bob; do
    id "$u" >/dev/null 2>&1 || run "sudo adduser --disabled-password --gecos '' $u"
done
run "getent group devteam >/dev/null || sudo groupadd devteam"
run "sudo usermod -aG devteam alice && sudo usermod -aG devteam bob"
run "id alice; id bob; getent group devteam"

section "A2 Shared project folder"
why "setgid (2) makes new files inherit the devteam group; 770 keeps others out"
run "sudo mkdir -p /srv/project && sudo chown root:devteam /srv/project && sudo chmod 2770 /srv/project"
run "ls -ld /srv/project"
run "sudo -u alice touch /srv/project/a.txt && sudo ls -l /srv/project"
run "ls /srv/project   # expected: Permission denied (I am not in devteam)"

section "A3 Permissions"
why "a script needs the x bit to run; 640 = owner rw, group r, others nothing"
run "cd ~ && echo 'echo Hello DevOps' > hello.sh && ./hello.sh; chmod u+x hello.sh && ./hello.sh"
run "cd ~ && touch notes.txt && chmod 640 notes.txt && ls -l hello.sh notes.txt"

section "A4 apt"
why "update refreshes the package list, install fetches packages with dependencies"
run "sudo apt update -qq"
run "sudo apt install -y -qq htop tree"
run "apt show tree 2>/dev/null | head -8"
run "sudo apt remove -y -qq tree && apt list --upgradable 2>/dev/null | head -5"

section "A5 systemctl"
why "start = now, enable = at boot; they are independent"
run "sudo apt install -y -qq nginx"
run "systemctl status nginx --no-pager | head -5"
run "curl -sI http://localhost | head -1"
run "sudo systemctl stop nginx; systemctl is-active nginx; sudo systemctl start nginx; systemctl is-active nginx; systemctl is-enabled nginx"

section "A6 Logs"
why "logs show who logged in and what failed"
run "journalctl -u ssh -n 20 --no-pager 2>/dev/null || sudo journalctl -u ssh -n 20 --no-pager"
run "sudo journalctl -p err -b --no-pager | tail -5"
run "sudo grep 'Accepted publickey' /var/log/auth.log | tail -3"

section "A7 Processes"
why "find a process by name and stop it politely with TERM"
run "ps -ef | grep [s]shd | head -3"
run "sleep 600 & pgrep -a sleep; pkill sleep; pgrep -a sleep || echo 'sleep stopped'"

section "B1 Network diagnosis"
why "check from the inside out: address, gateway, DNS, internet, service"
run "ip -br a"
run "ip route"
run "resolvectl status | grep -E 'DNS Servers|Current DNS' | head -3"
run "ping -c 3 8.8.8.8 || curl -sI http://example.com | head -1"
run "curl -sI localhost | head -1"

section "B2 Listening ports"
why "every listening port on 0.0.0.0 is reachable from the network and must be justified"
run "sudo ss -tulpn"

echo
echo "Saved to $OUT"
echo "Next: bash harden-ssh.sh   (Practical B3-B6), then: bash log-report.sh"
