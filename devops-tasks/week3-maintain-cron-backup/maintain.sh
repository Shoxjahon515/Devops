#!/usr/bin/env bash
# maintain.sh - back up a folder, rotate the log,
# keep the newest backups and check services.
# Usage: maintain.sh [source-folder]
# Exit code: 0 = everything OK, 1 = at least one step failed.

set -euo pipefail

# ---------- settings ----------
SRC="${1:-$HOME/project-data}"
BACKUP_DIR="$HOME/backups"
LOG_DIR="$HOME/logs"
LOG_FILE="$LOG_DIR/maintain.log"
KEEP=5                  # backups to keep
MAX_LOG_BYTES=51200     # rotate log above 50 KB
SERVICES=(ssh cron nginx)

mkdir -p "$BACKUP_DIR" "$LOG_DIR"

# ---------- helpers ----------
log() {
    echo "$(date '+%F %T') $*" >> "$LOG_FILE"
}

# ---------- steps ----------
backup() {
    if [[ ! -d "$SRC" ]]; then
        log "ERROR source $SRC not found"
        return 1
    fi

    local stamp archive
    # UTC: cron and an interactive shell can have different time zones; mixing them
    # would break the oldest-first name order that prune_backups relies on.
    # Milliseconds stop two runs in the same second from overwriting one archive.
    stamp=$(date -u +%Y%m%d-%H%M%S-%3N)
    archive="$BACKUP_DIR/backup-$stamp.tar.gz"

    if ! tar -czf "$archive" -C "$SRC" .; then
        log "ERROR tar failed for $SRC"
        rm -f -- "$archive"          # do not leave a half-written archive behind
        return 1
    fi
    log "OK backup $archive"
}

prune_backups() {
    # The glob expands in name order; the timestamp in the name makes that oldest-first.
    shopt -s nullglob
    local files=("$BACKUP_DIR"/backup-*.tar.gz)
    shopt -u nullglob

    local total=${#files[@]}
    local i
    for (( i = 0; i < total - KEEP; i++ )); do
        rm -f -- "${files[i]}"
        log "OK removed old backup ${files[i]}"
    done
}

rotate_log() {
    if [[ ! -f "$LOG_FILE" ]]; then
        return 0
    fi

    local size
    size=$(stat -c %s "$LOG_FILE")
    if (( size > MAX_LOG_BYTES )); then
        if [[ -f "$LOG_FILE.2" ]]; then
            mv "$LOG_FILE.2" "$LOG_FILE.3"
        fi
        if [[ -f "$LOG_FILE.1" ]]; then
            mv "$LOG_FILE.1" "$LOG_FILE.2"
        fi
        mv "$LOG_FILE" "$LOG_FILE.1"
        log "OK rotated log (was $size bytes)"
    fi
}

check_services() {
    local svc
    local failed=0
    for svc in "${SERVICES[@]}"; do
        if systemctl is-active --quiet "$svc"; then
            log "OK service $svc is running"
        else
            log "FAIL service $svc is not running"
            failed=1
        fi
    done
    return "$failed"
}

main() {
    local status=0

    # Only one copy at a time: a slow run must not overlap the next cron run.
    exec 9> "$LOG_DIR/.maintain.lock"
    if ! flock -n 9; then
        log "SKIP another maintain.sh run is still in progress"
        return 1
    fi

    rotate_log
    log "START source=$SRC"
    backup || status=1
    prune_backups
    check_services || status=1
    log "END status=$status"
    return "$status"
}

main
