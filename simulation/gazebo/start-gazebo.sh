#!/bin/bash
# Start Gazebo + ArduPilot SITL for drone-platform
# Usage: ./start-gazebo.sh [--headless]

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Parse arguments
HEADLESS=false
if [ "$1" = "--headless" ]; then
    HEADLESS=true
    echo -e "${BLUE}Running in headless mode (no GUI)${NC}"
fi

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    echo -e "${RED}Error: Docker is not running${NC}"
    exit 1
fi

# Setup X11 forwarding for GUI (if not headless)
if [ "$HEADLESS" = false ]; then
    if [ -z "$DISPLAY" ]; then
        echo -e "${YELLOW}Warning: DISPLAY not set, running in headless mode${NC}"
        HEADLESS=true
    else
        echo -e "${BLUE}Setting up X11 forwarding...${NC}"
        xhost +local:docker 2>/dev/null || true
    fi
fi

# Check if already running
if docker compose ps | grep -q "gazebo\|sitl-gazebo"; then
    echo -e "${YELLOW}Gazebo appears to be already running${NC}"
    echo "Run 'docker compose down' first to restart"
    exit 0
fi

# Build and start
echo -e "${GREEN}Starting Gazebo + ArduPilot SITL...${NC}"
echo ""

if [ "$HEADLESS" = true ]; then
    # Headless mode - override command
    echo -e "${BLUE}Starting in headless mode...${NC}"
    docker compose up --build -d
else
    # GUI mode
    docker compose up --build
fi

echo ""
echo -e "${GREEN}✓ Gazebo + SITL started${NC}"
echo ""
echo "Connection Details:"
echo "  MAVLink: tcp:127.0.0.1:5760"
echo "  Gazebo GUI: http://localhost:9002 (if not headless)"
echo ""
echo "Run mission:"
echo "  python3 -m autonomy.mission_manager --deployment deployments/full_sitl__gazebo.yaml"
echo ""
echo "Stop:"
echo "  docker compose down"
