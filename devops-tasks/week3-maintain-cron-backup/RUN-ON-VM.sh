#!/usr/bin/env bash
# RUN-ON-VM.sh - run Task 3 on your Ubuntu VM and collect all text evidence
# into ~/task3-evidence.txt. Screenshots (crontab -l, service-down run) you
# still take yourself - see the steps printed at the end.
#
# Usage (on the VM, in the folder where maintain.sh is):
#   bash RUN-ON-VM.sh            # step 1: install, test, add cron
#   bash RUN-ON-VM.sh collect    # step 2: after 10+ minutes, collect evidence
set -uo pipefail

OUT="$HOME/task3-evidence.txt"
SCRIPT="$HOME/scripts/maintain.sh"

section() { printf '\n===== %s =====\n' "$*" | tee -a "$OUT"; }
run() { printf '$ %s\n' "$*" | tee -a "$OUT"; bash -c "$*" 2>&1 | tee -a "$OUT"; }

if [[ "${1:-}" != "collect" ]]; then
    : > "$OUT"
    mkdir -p "$HOME/scripts" "$HOME/project-data" "$HOME/logs"
    cp maintain.sh "$SCRIPT" && chmod +x "$SCRIPT"
    for i in 1 2 3; do echo "file $i" > "$HOME/project-data/file$i.txt"; done
    sudo systemctl start nginx 2>/dev/null || true

    section "Syntax and quality"
    run "bash -n $SCRIPT && echo syntax OK"
    command -v shellcheck >/dev/null && run "shellcheck $SCRIPT && echo shellcheck: no warnings"

    section "Normal run"
    run "$SCRIPT; echo exit=\$?"

    section "Keep newest five (7 runs)"
    run "for i in {1..7}; do $SCRIPT; sleep 1; done; ls ~/backups | wc -l"

    section "Missing source"
    run "$SCRIPT /nope; echo exit=\$?"

    section "Restore test"
    run 'rm -rf /tmp/r; mkdir -p /tmp/r; tar -xzf "$(ls -1 ~/backups/backup-*.tar.gz | tail -1)" -C /tmp/r; ls /tmp/r'

    # cron entry, added only once
    LINE="*/5 * * * * $SCRIPT >> $HOME/logs/cron.log 2>&1"
    ( crontab -l 2>/dev/null | grep -vF "$SCRIPT"; echo "$LINE" ) | crontab -
    section "crontab -l"
    run "crontab -l"

    cat <<EOF

NEXT (do these yourself, they need screenshots):
 1. Screenshot:  crontab -l
 2. Service-down test, then screenshot the terminal:
      sudo systemctl stop nginx; ~/scripts/maintain.sh; echo \$?     # must print 1
      sudo systemctl start nginx
 3. Wait at least 10 minutes, then run:  bash RUN-ON-VM.sh collect
EOF
else
    section "tail -n 20 ~/logs/maintain.log (two cron runs)"
    run "tail -n 20 ~/logs/maintain.log"
    section "ls -l ~/backups (5 archives)"
    run "ls -l ~/backups"
    section "cron in syslog"
    run "grep CRON /var/log/syslog | grep maintain | tail -5"
    echo
    echo "Done. Text evidence is in $OUT - paste it into your submission."
    echo "Optional: change the schedule to daily 02:00 with: crontab -e  ->  0 2 * * *"
fi
