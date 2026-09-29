#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

require_command docker
require_command curl

cd "$PROJECT_DIR"

log_info "Starting Mattermost health check..."

failed=0

check_container() {
    local container="$1"

    if docker inspect "$container" >/dev/null 2>&1; then
        if [[ "$(docker inspect -f '{{.State.Running}}' "$container")" == "true" ]]; then
            log_success "Container is running: $container"
        else
            log_error "Container exists but is not running: $container"
            failed=1
        fi
    else
        log_error "Container not found: $container"
        failed=1
    fi
}

check_http() {
    local name="$1"
    local url="$2"
    local curl_options="$3"

    if curl $curl_options --silent --show-error --fail "$url" >/dev/null; then
        log_success "$name is responding: $url"
    else
        log_error "$name is not responding: $url"
        failed=1
    fi
}

log_info "Checking required containers..."

check_container "mattermost"
check_container "mattermost-postgres"

log_info "Checking Mattermost HTTP endpoint..."

check_http \
    "Mattermost direct HTTP" \
    "http://127.0.0.1:8065/api/v4/system/ping" \
    ""

log_info "Checking Nginx HTTPS endpoint..."

check_http \
    "Mattermost HTTPS" \
    "https://127.0.0.1/api/v4/system/ping" \
    "-k"

log_info "Checking Docker Compose configuration..."

if docker compose config -q; then
    log_success "Docker Compose configuration is valid."
else
    log_error "Docker Compose configuration is invalid."
    failed=1
fi

if [[ "$failed" -eq 0 ]]; then
    log_success "Mattermost health check PASSED."
    exit 0
else
    log_error "Mattermost health check FAILED."
    exit 1
fi
