#!/usr/bin/env bash
# shellcheck disable=SC1091
# log-report.sh - Week 2 Logs Report generator.
# Reads the real logs of this server and writes a Markdown investigation
# report: ~/week2-log-report.md
#
# Usage on the VM:  bash log-report.sh ["Your Name"]
# LOG_DIR can be overridden for testing (default /var/log).
set -euo pipefail

AUTHOR="${1:-Shoxjahon Tuymurodov}"
LOG_DIR="${LOG_DIR:-/var/log}"
OUT="${OUT:-$HOME/week2-log-report.md}"
SUDO=""; [[ $EUID -ne 0 && -z "${NO_SUDO:-}" ]] && SUDO="sudo"

# read a log including rotated and gzipped copies (auth.log, auth.log.1, auth.log.2.gz)
read_log() {
    local base="$1" f
    for f in "$LOG_DIR/$base".*.gz; do [[ -e "$f" ]] && $SUDO zcat -- "$f"; done
    for f in "$LOG_DIR/$base".1 "$LOG_DIR/$base"; do [[ -e "$f" ]] && $SUDO cat -- "$f"; done
    return 0
}
count() { grep -cE "$1" <<< "$2" || true; }
or_none() { local x; x=$(cat); if [[ -n "$x" ]]; then printf '%s\n' "$x"; else echo "(none in this period)"; fi; }
table_top() {   # stdin: "count value" lines -> markdown rows
    local n=0 c v
    while read -r c v; do
        printf '| %s | %s |\n' "$v" "$c"; n=$((n + 1))
    done
    (( n > 0 )) || printf '| (none) | 0 |\n'
}

AUTH=$(read_log auth.log)
SYSLOG=$(read_log syslog)
ACCESS=$( { read_log nginx/access.log; read_log apache2/access.log; } )

FAILED=$(count 'Failed (password|publickey) for' "$AUTH")
INVALID=$(count 'Invalid user' "$AUTH")
ACC_KEY=$(count 'Accepted publickey' "$AUTH")
ACC_PW=$(count 'Accepted password' "$AUTH")
SUDO_N=$(grep -E 'sudo: .*COMMAND=' <<< "$AUTH" | grep -vcE 'NOT in sudoers|incorrect password' || true)
SUDO_FAIL=$(count 'sudo: .*(incorrect password|NOT in sudoers)' "$AUTH")
PERIOD_FROM=$(head -n1 <<< "$AUTH" | awk '{print $1, $2, $3}')
PERIOD_TO=$(tail -n1 <<< "$AUTH" | awk '{print $1, $2, $3}')
ERR_N=$($SUDO journalctl -p err -b --no-pager -q 2>/dev/null | wc -l || echo 0)
HTTP_TOTAL=$(grep -c . <<< "$ACCESS" || true)
HTTP_4XX=$(awk '$9 ~ /^4/' <<< "$ACCESS" | wc -l)
HTTP_5XX=$(awk '$9 ~ /^5/' <<< "$ACCESS" | wc -l)
DISK=$(df -h / | awk 'NR==2 {print $5 " used of " $2}')

# risk level from the evidence
RISK="Low"
(( FAILED > 20 || ACC_PW > 0 )) && RISK="Medium"
(( FAILED > 100 || SUDO_FAIL > 5 )) && RISK="High"

{
cat <<EOF
# Server Log Investigation Report

| | |
|---|---|
| **Report** | Week 2 Logs Report — Unit 4 DevOps |
| **Prepared by** | $AUTHOR, group 23-309 |
| **Server** | $(hostname) ($(hostname -I 2>/dev/null | awk '{print $1}')) · $(. /etc/os-release && echo "$PRETTY_NAME") |
| **Date of report** | $(date '+%F %H:%M') |
| **Period covered** | ${PERIOD_FROM:-n/a} → ${PERIOD_TO:-n/a} (auth.log incl. rotated files) |
| **Overall risk** | **$RISK** |

## 1. Purpose

Check the server's logs for security events (logins, failed logins, privilege use), service errors and web traffic, explain what they mean and recommend actions. This follows the Week 2 practical, where the server was hardened (SSH on port 2222, key-only login, no root login, ufw default deny).

## 2. Logs examined

| Log | Location | What it records |
|---|---|---|
| Authentication | \`/var/log/auth.log\` | SSH logins (accepted / failed), sudo use, user and group changes |
| System | \`/var/log/syslog\` | services, cron, kernel and general system messages |
| systemd journal | \`journalctl\` | structured logs of every service (\`-u ssh\`, \`-p err\`) |
| Web access | \`/var/log/nginx/access.log\`, \`/var/log/apache2/access.log\` | every HTTP request: client, path, status code |

## 3. Summary of findings

| Indicator | Value |
|---|---|
| Failed SSH login attempts | $FAILED |
| … of which for non-existent users | $INVALID |
| Successful logins with a key | $ACC_KEY |
| Successful logins with a password | $ACC_PW |
| sudo commands run | $SUDO_N |
| Failed sudo attempts | $SUDO_FAIL |
| Errors in the journal since boot | $ERR_N |
| HTTP requests (4xx / 5xx) | $HTTP_TOTAL ($HTTP_4XX / $HTTP_5XX) |
| Disk usage of / | $DISK |

## 4. Detailed findings

### 4.1 Failed logins by source IP

| Source IP | Attempts |
|---|---|
EOF
grep -E 'Failed (password|publickey) for' <<< "$AUTH" | grep -oE 'from [0-9a-fA-F:.]+' | awk '{print $2}' \
    | sort | uniq -c | sort -rn | head -10 | table_top

cat <<'EOF'

### 4.2 User names tried by attackers

| User name | Attempts |
|---|---|
EOF
grep -oE 'Failed (password|publickey) for (invalid user )?[^ ]+' <<< "$AUTH" | awk '{print $NF}' | sort | uniq -c | sort -rn | head -10 | table_top

cat <<'EOF'

### 4.3 Successful logins (last 10)

```
EOF
grep -E 'Accepted (publickey|password)' <<< "$AUTH" | tail -10 \
    | sed -E 's/^(.{15}).*Accepted ([a-z]+) for ([^ ]+) from ([^ ]+) port ([0-9]+).*/\1  \2  user=\3  from=\4  port=\5/' | or_none || true
cat <<'EOF'
```

### 4.4 Privilege use (sudo, last 10)

```
EOF
grep -E 'sudo: .*COMMAND=' <<< "$AUTH" | grep -vE 'NOT in sudoers|incorrect password' | tail -10 \
    | sed -E 's/^(.{15}).*sudo: +([^ ]+) : .*COMMAND=(.*)$/\1  \2  \3/' | or_none || true
cat <<'EOF'
```

### 4.5 Account changes (useradd / groupadd / usermod)

```
EOF
grep -E 'useradd|groupadd|usermod|new user|new group|add .* to group' <<< "$AUTH" | tail -10 | cut -c1-160 | or_none || true
cat <<'EOF'
```

### 4.6 Service errors (journal, priority err, since boot)

```
EOF
{ $SUDO journalctl -p err -b --no-pager -q 2>/dev/null || true; } | tail -10 | cut -c1-160 | or_none
cat <<'EOF'
```

### 4.7 SSH service events

```
EOF
grep -E 'sshd.*(Server listening|Received signal|Received SIGHUP)' <<< "$AUTH$SYSLOG" | tail -6 | cut -c1-160 | or_none || true
cat <<'EOF'
```

### 4.8 Web traffic — top requested paths and status codes

| Path | Requests |
|---|---|
EOF
awk '{print $7}' <<< "$ACCESS" | grep -v '^$' | sort | uniq -c | sort -rn | head -8 | table_top
cat <<'EOF'

| Status code | Requests |
|---|---|
EOF
awk '{print $9}' <<< "$ACCESS" | grep -E '^[0-9]{3}$' | sort | uniq -c | sort -rn | table_top

cat <<EOF

### 4.9 Firewall and listening ports at the time of the report

\`\`\`
$($SUDO ufw status 2>/dev/null | head -12 || echo "ufw not available")

$($SUDO ss -tlnp 2>/dev/null | awk 'NR==1 || /LISTEN/' | cut -c1-120)
\`\`\`

## 5. Analysis

EOF

if (( FAILED > 0 )); then
    echo "- **Brute-force attempts were found ($FAILED failed attempts).** Repeated failures for common names (root, admin, test, ubuntu) from the same IP are automated password guessing. Because password authentication is now disabled (\`PasswordAuthentication no\`), these attempts cannot succeed: without the private key there is nothing to guess."
else
    echo "- **No failed SSH logins were recorded** in the period. This is expected for a lab VM on a private network; on a public server failed logins usually start within minutes."
fi
if (( ACC_PW > 0 )); then
    echo "- **$ACC_PW login(s) used a password.** These happened before hardening. After \`PasswordAuthentication no\` every new login should show \`Accepted publickey\`; a new \`Accepted password\` line would mean the hardening file is not active (check \`sudo sshd -T | grep passwordauthentication\`)."
fi
echo "- **Logins with a key: $ACC_KEY.** Each one is listed with user, source IP and port, so every session can be traced to a person and a machine."
echo "- **sudo was used $SUDO_N times** and every command is recorded with the user and full command line — this is why administrators use sudo instead of logging in as root. Failed sudo attempts: $SUDO_FAIL."
(( SUDO_FAIL > 0 )) && echo "  Failed sudo attempts should be checked: a wrong password is normal, \`NOT in sudoers\` means a user tried to get root rights they do not have."
if (( ERR_N > 0 )); then
    echo "- **$ERR_N error lines in the journal since boot.** On a VirtualBox VM many are harmless hardware/driver messages (e.g. vmwgfx, piix4_smbus); errors from ssh, nginx or apt need action."
else
    echo "- **No error-level messages in the journal since the last boot.**"
fi
if (( HTTP_TOTAL > 0 )); then
    echo "- **Web server: $HTTP_TOTAL requests, $HTTP_4XX client errors (4xx), $HTTP_5XX server errors (5xx).** 404s for paths such as \`/wp-login.php\` or \`/.env\` are scanners looking for weak sites; 5xx errors would mean the service itself is failing."
fi

cat <<'EOF'

## 6. Recommendations

| # | Action | Reason | Status |
|---|---|---|---|
| 1 | Keep key-only SSH, no root login, port 2222 | removes password guessing; root cannot log in directly | done in Practical B |
| 2 | ufw default deny incoming, allow only 2222/tcp and 80/tcp | only needed services are reachable | done in Practical B |
| 3 | Install fail2ban for sshd | bans IPs after repeated failures, reduces log noise | recommended |
| 4 | Review `auth.log` weekly; alert on `Accepted password` and `NOT in sudoers` | detects misuse early | recommended |
| 5 | Keep logrotate enabled and watch disk space | full disk stops logging and services | in place (Ubuntu default) |
| 6 | `apt update && apt upgrade` on a schedule | patches known vulnerabilities | recommended |
| 7 | Send logs to a central system later (journald → Loki/ELK) | logs on a hacked server can be deleted | later in the course |

## 7. Commands used

```bash
sudo grep 'Failed password' /var/log/auth.log | grep -oE 'from [0-9.]+' | sort | uniq -c | sort -rn
sudo grep -E 'Accepted (publickey|password)' /var/log/auth.log | tail
sudo grep 'COMMAND=' /var/log/auth.log | tail
journalctl -u ssh -n 20 --no-pager
sudo journalctl -p err -b --no-pager
awk '{print $9}' /var/log/nginx/access.log | sort | uniq -c
sudo ss -tulpn ; sudo ufw status numbered
```

## 8. Conclusion

EOF
echo "The logs show the server's security state clearly. Overall risk is assessed as **$RISK**. The hardening done in Week 2 (keys only, no root login, firewall default deny) closes the main attack path seen in the logs — password guessing over SSH — and every remaining administrative action is traceable through auth.log and the journal."
} > "$OUT"

echo "Report written to $OUT"
echo "Convert to Word/PDF if needed:  pandoc $OUT -o week2-log-report.docx"
