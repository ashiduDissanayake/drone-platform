#!/bin/bash
# Unified SITL management script
# Supports: local Docker SITL (modern Copter 4.x)
# Usage: ./ops/scripts/sitl.sh [start|stop|status|logs] [--modern|--local]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Default to modern SITL (Copter 4.x)
MODE="modern"
COMPOSE_FILE="${REPO_ROOT}/infra/compose/docker-compose.sitl-modern.yaml"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_debug() {
    echo -e "${BLUE}[DEBUG]${NC} $1"
}

show_help() {
    cat << EOF
Usage: $0 [COMMAND] [OPTIONS]

Commands:
  start    Start ArduPilot SITL
  stop     Stop SITL
  status   Check if SITL is running
  logs     View SITL logs
  shell    Open shell in SITL container

Options:
  --modern    Use modern SITL (Copter 4.x) [default]
  --local     Use local SITL build (requires ArduPilot compiled)

Examples:
  $0 start              # Start modern SITL
  $0 start --local      # Start local SITL
  $0 status             # Check status
  $0 stop               # Stop SITL
  $0 logs               # View logs

Connection:
  Modern: tcp:127.0.0.1:5760 (Docker container with Copter 4.x)
  Local:  tcp:127.0.0.1:5760 (Your compiled ArduPilot)

EOF
}

parse_args() {
    COMMAND=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            start|stop|status|logs|shell)
                COMMAND="$1"
                shift
                ;;
            --modern)
                MODE="modern"
                COMPOSE_FILE="${REPO_ROOT}/infra/compose/docker-compose.sitl-modern.yaml"
                shift
                ;;
            --local)
                MODE="local"
                COMPOSE_FILE="${REPO_ROOT}/infra/compose/docker-compose.sitl.yaml"
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    if [ -z "$COMMAND" ]; then
        show_help
        exit 1
    fi
}

cmd_start() {
    log_info "Starting ArduPilot SITL (mode: $MODE)..."
    
    if [ ! -f "${COMPOSE_FILE}" ]; then
        log_error "Docker Compose file not found: ${COMPOSE_FILE}"
        exit 1
    fi
    
    log_debug "Using compose file: ${COMPOSE_FILE}"
    
    if [ "$MODE" = "modern" ]; then
        log_info "Pulling latest SITL image..."
        docker compose -f "${COMPOSE_FILE}" pull
    fi
    
    docker compose -f "${COMPOSE_FILE}" up -d
    
    log_info "Waiting for SITL to be ready..."
    for i in {1..30}; do
        if nc -z localhost 5760 2>/dev/null; then
            log_info "✓ SITL is ready!"
            log_info "  Connection: tcp:127.0.0.1:5760"
            log_info "  Mode: $MODE"
            if [ "$MODE" = "modern" ]; then
                log_info "  Note: This SITL will arm properly!"
            fi
            return 0
        fi
        sleep 1
    done
    
    log_error "SITL failed to start within 30 seconds"
    log_info "Check logs with: $0 logs --$MODE"
    exit 1
}

cmd_stop() {
    log_info "Stopping ArduPilot SITL (mode: $MODE)..."
    docker compose -f "${COMPOSE_FILE}" down
    log_info "SITL stopped"
}

cmd_status() {
    if docker compose -f "${COMPOSE_FILE}" ps 2>/dev/null | grep -q "Up"; then
        log_info "SITL is running (mode: $MODE)"
        log_info "  Connection: tcp:127.0.0.1:5760"
        return 0
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
parse_args "$@"

case "$COMMAND" in
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
        log_error "Unknown command: $COMMAND"
        show_help
        exit 1
        ;;
esac
