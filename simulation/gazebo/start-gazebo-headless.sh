#!/bin/bash
# Start Gazebo + ArduPilot in HEADLESS mode (most reliable)
# No GUI, just physics + MAVLink

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=========================================="
echo "  Gazebo + ArduPilot (Headless Mode)"
echo "=========================================="
echo ""

# Check Docker
if ! docker info >/dev/null 2>&1; then
    echo "Error: Docker is not running"
    exit 1
fi

# Stop any existing
docker compose -f docker-compose.headless.yaml down 2>/dev/null || true

echo "Starting Gazebo Server + ArduPilot SITL..."
echo ""

# Rebuild with fixed paths
docker compose -f docker-compose.headless.yaml up --build -d

echo ""
echo "✓ Gazebo + SITL started in headless mode"
echo ""
echo "Connection Details:"
echo "  MAVLink: tcp:127.0.0.1:5760"
echo ""
echo "Run mission:"
echo "  python3 -m autonomy.mission_manager --deployment deployments/full_sitl__gazebo.yaml"
echo ""
echo "View logs:"
echo "  docker compose -f docker-compose.headless.yaml logs -f"
echo ""
echo "Stop:"
echo "  docker compose -f docker-compose.headless.yaml down"
echo ""

# Show logs
docker compose -f docker-compose.headless.yaml logs -f
