#!/bin/bash
# Start Gazebo + ArduPilot SITL for drone-platform

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Gazebo + ArduPilot SITL${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check Docker
if ! docker info >/dev/null 2>&1; then
    echo -e "${RED}Error: Docker is not running${NC}"
    exit 1
fi

# Setup X11
if [ -n "$DISPLAY" ]; then
    echo -e "${BLUE}Setting up X11 forwarding...${NC}"
    xhost +local:docker 2>/dev/null || true
fi

# Stop any existing containers
echo -e "${BLUE}Cleaning up existing containers...${NC}"
docker compose -f docker-compose.gazebo.yaml down 2>/dev/null || true

# Start containers
echo ""
echo -e "${GREEN}Starting Gazebo + ArduPilot SITL...${NC}"
echo -e "${YELLOW}This will take a moment to download models...${NC}"
echo ""

# Run in detached mode first to handle model downloads
docker compose -f docker-compose.gazebo.yaml up -d

echo ""
echo -e "${GREEN}✓ Containers started${NC}"
echo ""
echo "Connection Details:"
echo "  MAVLink: tcp:127.0.0.1:5760"
echo ""
echo "View logs:"
echo "  docker compose -f docker-compose.gazebo.yaml logs -f"
echo ""
echo "Run mission:"
echo "  python3 -m autonomy.mission_manager --deployment deployments/full_sitl__gazebo.yaml"
echo ""
echo "Stop:"
echo "  docker compose -f docker-compose.gazebo.yaml down"
echo ""

# Show logs
echo -e "${BLUE}Showing logs (Ctrl+C to exit logs, containers keep running):${NC}"
docker compose -f docker-compose.gazebo.yaml logs -f || true
