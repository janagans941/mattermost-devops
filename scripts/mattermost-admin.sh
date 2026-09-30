#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

# The wrapper dispatches to child scripts that manage their own EXIT traps.
trap - EXIT

require_command docker

cd "$PROJECT_DIR"

run_health() {
    ./scripts/health-check.sh
}

run_docker_health() {
    ./scripts/docker-health.sh
}

run_diagnostics() {
    ./scripts/diagnose-services.sh
}

run_backup() {
    ./scripts/backup-mattermost.sh
}

run_summary() {
    ./scripts/system-summary.sh
}

show_status() {
    log_info "Mattermost Docker service status:"
    docker compose ps
}

run_command() {
    local command="$1"

    case "$command" in
        health)
            run_health
            ;;
        docker)
            run_docker_health
            ;;
        diagnose)
            run_diagnostics
            ;;
        backup)
            run_backup
            ;;
        summary)
            run_summary
            ;;
        status)
            show_status
            ;;
        "")
            return 1
            ;;
        *)
            log_error "Unknown command: $command"
            echo
            echo "Usage:"
            echo "  $0"
            echo "  $0 health"
            echo "  $0 docker"
            echo "  $0 diagnose"
            echo "  $0 backup"
            echo "  $0 summary"
            echo "  $0 status"
            return 1
            ;;
    esac
}

show_menu() {
    echo
    echo "========================================"
    echo "      Mattermost Administration"
    echo "========================================"
    echo
    echo "1. Health check"
    echo "2. Docker health"
    echo "3. Generate diagnostics"
    echo "4. Create backup"
    echo "5. System summary"
    echo "6. Show service status"
    echo "7. Exit"
    echo
}

if [[ "$#" -gt 0 ]]; then
    run_command "$1"
    exit $?
fi

while true; do
    show_menu

    read -r -p "Select an option [1-7]: " choice

    case "$choice" in
        1)
            run_health
            ;;
        2)
            run_docker_health
            ;;
        3)
            run_diagnostics
            ;;
        4)
            run_backup
            ;;
        5)
            run_summary
            ;;
        6)
            show_status
            ;;
        7)
            log_info "Exiting Mattermost administration."
            exit 0
            ;;
        *)
            log_warn "Invalid option. Please select 1-7."
            ;;
    esac
done
