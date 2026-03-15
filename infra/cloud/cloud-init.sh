#!/bin/bash
# Cloud SITL Setup Script for AWS/GCP
# Run this on a fresh Ubuntu 22.04 instance

set -e

echo "=== Setting up ArduPilot SITL on Cloud ==="

# Update system
sudo apt-get update
sudo apt-get install -y git python3 python3-pip python3-dev \
    python3-opencv python3-wxgtk4.0 python3-matplotlib \
    python3-lxml python3-scipy g++ make gcc gawk wget curl netcat

# Install Python packages
pip3 install --user pymavlink mavproxy dronekit pyserial pexpect

# Clone ArduPilot
cd ~
if [ ! -d "ardupilot" ]; then
    echo "Cloning ArduPilot (this takes a while)..."
    git clone --depth 1 --recursive https://github.com/ArduPilot/ardupilot.git
fi

cd ardupilot

# Install ArduPilot dependencies
pip3 install --user -U future lxml pymavlink MAVProxy

# Configure and build SITL
echo "Building SITL (this takes 10-15 minutes)..."
./waf configure --board sitl
./waf copter

echo ""
echo "=== ArduPilot SITL Built Successfully ==="
echo ""
echo "To start SITL with public access:"
echo "  cd ~/ardupilot"
echo "  python3 Tools/autotest/sim_vehicle.py -v ArduCopter -L Home --out tcp:0.0.0.0:5760"
echo ""
echo "SITL will be available on port 5760"
