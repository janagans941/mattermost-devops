#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

require_command docker

cd "$PROJECT_DIR"

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
    echo "5. Show service status"
    echo "6. Exit"
    echo
}

show_status() {
    log_info "Mattermost Docker service status:"
    docker compose ps
}

while true; do
    show_menu

    read -r -p "Select an option [1-6]: " choice

    case "$choice" in
        1)
            ./scripts/health-check.sh
            ;;
        2)
            ./scripts/docker-health.sh
            ;;
        3)
            ./scripts/diagnose-services.sh
            ;;
        4)
            ./scripts/backup-mattermost.sh
            ;;
        5)
            show_status
            ;;
        6)
            log_info "Exiting Mattermost administration."
            exit 0
            ;;
        *)
            log_warn "Invalid option. Please select 1-6."
            ;;
    esac
done
