#!/bin/bash
# Helper script for managing ArduPilot SITL
# Usage: ./ops/scripts/sitl.sh [start|stop|status|logs]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
COMPOSE_FILE="${REPO_ROOT}/infra/compose/docker-compose.sitl.yaml"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

cmd_start() {
    log_info "Starting ArduPilot SITL..."
    
    if [ ! -f "${COMPOSE_FILE}" ]; then
        log_error "Docker Compose file not found: ${COMPOSE_FILE}"
        exit 1
    fi
    
    docker compose -f "${COMPOSE_FILE}" up -d
    
    log_info "Waiting for SITL to be ready..."
    for i in {1..30}; do
        if nc -z localhost 5760 2>/dev/null; then
            log_info "SITL is ready!"
            log_info "Connection: tcp:127.0.0.1:5760"
            log_info "MAVProxy GCS: udp:127.0.0.1:14550"
            return 0
        fi
        sleep 1
    done
    
    log_error "SITL failed to start within 30 seconds"
    log_info "Check logs with: $0 logs"
    exit 1
}

cmd_stop() {
    log_info "Stopping ArduPilot SITL..."
    docker compose -f "${COMPOSE_FILE}" down
    log_info "SITL stopped"
}

cmd_status() {
    if nc -z localhost 5760 2>/dev/null; then
        log_info "SITL is running"
        log_info "  Connection: tcp:127.0.0.1:5760"
        log_info "  MAVLink UDP: udp:127.0.0.1:14550"
    else
        log_warn "SITL is not running"
        return 1
    fi
}

cmd_logs() {
    docker compose -f "${COMPOSE_FILE}" logs -f
}

cmd_shell() {
    docker compose -f "${COMPOSE_FILE}" exec ardupilot-sitl bash
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
    shell)
        cmd_shell
        ;;
    *)
        echo "Usage: $0 [start|stop|status|logs|shell]"
        echo ""
        echo "Commands:"
        echo "  start   - Start ArduPilot SITL (Docker)"
        echo "  stop    - Stop SITL"
        echo "  status  - Check if SITL is running"
        echo "  logs    - View SITL logs"
        echo "  shell   - Open shell in SITL container"
        echo ""
        echo "Examples:"
        echo "  $0 start"
        echo "  $0 status && python3 -m autonomy.mission_manager --deployment deployments/full_sitl__single_device.yaml --start-sitl"
        exit 1
        ;;
esac
