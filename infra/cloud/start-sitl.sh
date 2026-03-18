#!/bin/bash
# Start SITL with public TCP access on cloud instance

cd ~/ardupilot

# Kill any existing SITL
pkill -f sim_vehicle.py 2>/dev/null || true
pkill -f arducopter 2>/dev/null || true
sleep 2

echo "Starting ArduPilot SITL on tcp:0.0.0.0:5760..."
echo "Waiting for GPS lock (takes ~30 seconds)..."

python3 Tools/autotest/sim_vehicle.py \
    -v ArduCopter \
    -L Home \
    --out tcp:0.0.0.0:5760 \
    --out udp:0.0.0.0:14550 \
    --no-rebuild
