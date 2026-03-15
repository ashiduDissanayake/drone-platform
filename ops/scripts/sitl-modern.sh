#!/bin/bash
# Modern ArduPilot SITL helper (Copter 4.x - actually arms!)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
COMPOSE_FILE="${REPO_ROOT}/infra/compose/docker-compose.sitl-modern.yaml"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

cmd_start() {
    log_info "Starting modern ArduPilot SITL (Copter 4.x)..."
    
    if [ ! -f "${COMPOSE_FILE}" ]; then
        log_error "Docker Compose file not found: ${COMPOSE_FILE}"
        exit 1
    fi
    
    # Pull latest image
    log_info "Pulling SITL image..."
    docker compose -f "${COMPOSE_FILE}" pull
    
    # Start SITL
    log_info "Starting container..."
    docker compose -f "${COMPOSE_FILE}" up -d
    
    log_info "Waiting for SITL to be ready..."
    for i in {1..30}; do
        if nc -z localhost 5760 2>/dev/null; then
            log_info "SITL is ready!"
            log_info "Connection: tcp:127.0.0.1:5760"
            log_info ""
            log_info "This SITL will arm properly! Try:"
            log_info "  python3 -m autonomy.mission_manager \\"
            log_info "    --deployment deployments/full_sitl__single_device.yaml \\"
            log_info "    --vehicle-backend ardupilot_sitl \\"
            log_info "    --connection tcp:127.0.0.1:5760"
            return 0
        fi
        sleep 1
    done
    
    log_error "SITL failed to start within 30 seconds"
    docker compose -f "${COMPOSE_FILE}" logs
    exit 1
}

cmd_stop() {
    log_info "Stopping ArduPilot SITL..."
    docker compose -f "${COMPOSE_FILE}" down
    log_info "SITL stopped"
}

cmd_status() {
    if docker compose -f "${COMPOSE_FILE}" ps | grep -q "Up"; then
        log_info "SITL is running (modern Copter 4.x)"
        log_info "  Connection: tcp:127.0.0.1:5760"
    else
        echo "SITL is not running"
        return 1
    fi
}

cmd_logs() {
    docker compose -f "${COMPOSE_FILE}" logs -f
}

# Main
case "${1:-}" in
    start)
        cmd_start
        ;;
    stop)
        cmd_stop
        ;;
    status)
        cmd_status
        ;;
    logs)
        cmd_logs
        ;;
    *)
        echo "Usage: $0 [start|stop|status|logs]"
        echo ""
        echo "Modern SITL (Copter 4.x) - Actually arms!"
        echo ""
        echo "Commands:"
        echo "  start   - Start modern ArduPilot SITL"
        echo "  stop    - Stop SITL"
        echo "  status  - Check if SITL is running"
        echo "  logs    - View SITL logs"
        echo ""
        exit 1
        ;;
esac
