#!/bin/bash
# User data script for EC2 SITL instance
# Runs on first boot, prepares system for Ansible configuration

set -e

exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "=== Drone Platform SITL - Cloud Init ==="
echo "Started at: $(date)"

# Update system packages
echo "Updating packages..."
apt-get update
apt-get upgrade -y

# Install dependencies for Ansible and SITL
echo "Installing base dependencies..."
apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    git \
    curl \
    wget \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    build-essential \
    g++ \
    gcc \
    gawk

# Install Ansible for local configuration
echo "Installing Ansible..."
pip3 install --user ansible

# Create ansible user data directory
mkdir -p /opt/drone-platform
chown ubuntu:ubuntu /opt/drone-platform

# Write ansible inventory for localhost
cat > /opt/drone-platform/inventory.yml << 'INVENTORY_EOF'
all:
  children:
    sim_host:
      hosts:
        localhost:
          ansible_connection: local
          ansible_python_interpreter: /usr/bin/python3
INVENTORY_EOF

chown ubuntu:ubuntu /opt/drone-platform/inventory.yml

echo "=== Base setup complete ==="
echo "Ansible will complete the configuration"
echo "Finished at: $(date)"

# Note: Full ArduPilot build is handled by Ansible
# This keeps user-data fast and allows for configuration management
