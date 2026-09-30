#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

require_command docker
require_command df
require_command free
require_command uptime
require_command ss

cd "$PROJECT_DIR"

log_info "Generating Mattermost system summary..."

echo
echo "========================================"
echo "       Mattermost System Summary"
echo "========================================"
echo

echo "=== Mattermost Status ==="

if docker inspect mattermost >/dev/null 2>&1; then
    state="$(docker inspect -f '{{.State.Status}}' mattermost)"

    if [[ "$state" == "running" ]]; then
        echo "Mattermost container : RUNNING"
    else
        echo "Mattermost container : $state"
    fi
else
    echo "Mattermost container : NOT FOUND"
fi

echo

echo "=== Docker Services ==="
docker compose ps

echo

echo "=== Disk Usage ==="
df -h "$PROJECT_DIR"

echo

echo "=== Memory Usage ==="
free -h

echo

echo "=== System Load ==="
uptime

echo

echo "=== Listening Ports ==="
ss -lnt

echo

echo "=== Recent Diagnostic Reports ==="

REPORT_DIR="${LOG_DIR}/diagnostics"

if [[ -d "$REPORT_DIR" ]]; then
    find "$REPORT_DIR" \
        -maxdepth 1 \
        -type f \
        -name 'diagnostic_*.log' \
        -printf '%T@ %p\n' \
        | sort -nr \
        | head -5 \
        | cut -d' ' -f2-
else
    echo "No diagnostic reports found."
fi

echo

echo "=== Latest Backup ==="

BACKUP_ROOT="${PROJECT_DIR}/backups"

if [[ -d "$BACKUP_ROOT" ]]; then
    latest_backup="$(
        find "$BACKUP_ROOT" \
            -mindepth 1 \
            -maxdepth 1 \
            -type d \
            -printf '%T@ %p\n' \
            | sort -nr \
            | head -1 \
            | cut -d' ' -f2-
    )"

    if [[ -n "$latest_backup" ]]; then
        echo "$latest_backup"
        echo
        ls -lh "$latest_backup"
    else
        echo "No backups found."
    fi
else
    echo "Backup directory does not exist."
fi

echo

echo "========================================"
echo "System summary completed."
echo "========================================"

exit 0
