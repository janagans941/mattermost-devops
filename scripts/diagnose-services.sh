#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

require_command docker

cd "$PROJECT_DIR"

log_info "Starting Mattermost service diagnostics..."

REPORT_DIR="${LOG_DIR}/diagnostics"
TIMESTAMP="$(date '+%Y%m%d_%H%M%S')"
REPORT_FILE="${REPORT_DIR}/diagnostic_${TIMESTAMP}.log"

mkdir -p "$REPORT_DIR"

{
    echo "========================================"
    echo "Mattermost Docker Diagnostic Report"
    echo "Generated: $(timestamp)"
    echo "========================================"
    echo

    echo "=== Docker Version ==="
    docker version
    echo

    echo "=== Docker Compose Version ==="
    docker compose version
    echo

    echo "=== Compose Service Status ==="
    docker compose ps
    echo

    echo "=== Container State / Health / Restart Count ==="
    docker inspect -f \
        '{{.Name}} | State={{.State.Status}} | Health={{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}} | Restarts={{.RestartCount}}' \
        mattermost \
        mattermost-postgres \
        mattermost-prometheus \
        mattermost-alertmanager \
        mattermost-loki \
        mattermost-alloy \
        mattermost-cadvisor
    echo

    echo "=== Docker Disk Usage ==="
    docker system df
    echo

    echo "=== Docker Compose Configuration Check ==="
    if docker compose config -q; then
        echo "Compose configuration: VALID"
    else
        echo "Compose configuration: INVALID"
    fi
    echo

    echo "=== Recent Container Logs ==="
    for container in \
        mattermost \
        mattermost-postgres \
        mattermost-prometheus \
        mattermost-alertmanager \
        mattermost-loki \
        mattermost-alloy \
        mattermost-cadvisor
    do
        echo
        echo "----------------------------------------"
        echo "Container: $container"
        echo "----------------------------------------"
        docker logs --tail 50 "$container" 2>&1 || true
    done

} > "$REPORT_FILE"

log_success "Diagnostic report created:"
log_success "$REPORT_FILE"

log_info "Report size:"
du -h "$REPORT_FILE"

exit 0
