#!/usr/bin/env bash

set -Eeuo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG_DIR="${PROJECT_DIR}/logs"

mkdir -p "$LOG_DIR"

timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

log_info() {
    echo "[$(timestamp)] [INFO] $*"
}

log_success() {
    echo "[$(timestamp)] [SUCCESS] $*"
}

log_warn() {
    echo "[$(timestamp)] [WARN] $*" >&2
}

log_error() {
    echo "[$(timestamp)] [ERROR] $*" >&2
}

require_command() {
    local command_name="$1"

    if ! command -v "$command_name" >/dev/null 2>&1; then
        log_error "Required command not found: $command_name"
        exit 1
    fi
}

cleanup_on_exit() {
    local exit_code=$?

    if [[ "$exit_code" -eq 0 ]]; then
        log_success "Script completed successfully."
    else
        log_error "Script failed with exit code: $exit_code"
    fi

    exit "$exit_code"
}

trap cleanup_on_exit EXIT
