#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

require_command docker

cd "$PROJECT_DIR"

log_info "Starting Docker service health check..."

failed=0

log_info "Checking Docker daemon..."

if docker info >/dev/null 2>&1; then
    log_success "Docker daemon is available."
else
    log_error "Docker daemon is not available."
    exit 1
fi

log_info "Checking Docker Compose configuration..."

if docker compose config -q; then
    log_success "Docker Compose configuration is valid."
else
    log_error "Docker Compose configuration is invalid."
    exit 1
fi

log_info "Checking Compose services..."

while IFS= read -r service; do
    [[ -z "$service" ]] && continue

    container="$(docker compose ps -aq --all "$service" 2>/dev/null || true)"

    if [[ -z "$container" ]]; then
        log_error "Container does not exist for service: $service"
        failed=1
        continue
    fi

    state="$(docker inspect -f '{{.State.Status}}' "$container" 2>/dev/null || echo "unknown")"

    if [[ "$state" == "running" ]]; then
        log_success "Service is running: $service"
    else
        log_error "Service is not running: $service - state: $state"
        failed=1
    fi
done < <(docker compose config --services)

if [[ "$failed" -eq 0 ]]; then
    log_success "All Docker Compose services are running."
else
    log_error "One or more Docker Compose services are not running."
    exit 1
fi
