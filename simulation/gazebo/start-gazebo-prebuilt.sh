#!/bin/bash
# Start Gazebo + ArduPilot using PRE-BUILT image (no compilation!)

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Gazebo + ArduPilot (Pre-built)${NC}"
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

# Pull latest image (only downloads, no build!)
echo -e "${BLUE}Pulling pre-built image (this may take a few minutes)...${NC}"
docker pull ardupilot/ardupilot-gazebo-sitl:latest

echo ""
echo -e "${GREEN}Starting Gazebo + ArduPilot...${NC}"
docker compose -f docker-compose.prebuilt.yaml up
