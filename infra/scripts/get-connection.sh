#!/bin/bash
# Get connection details from existing Terraform infrastructure
# Usage: source ./get-connection.sh

set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT/infra/terraform"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check if Terraform state exists
if [ ! -f terraform.tfstate ]; then
    echo -e "${RED}Error: No Terraform state found.${NC}"
    echo "Run ./setup-cloud-sitl.sh first to create infrastructure."
    exit 1
fi

# Get outputs
export SITL_IP=$(terraform output -raw sitl_public_ip 2>/dev/null)
export SITL_CONNECTION=$(terraform output -raw sitl_connection_string 2>/dev/null)
export SSH_KEY="${REPO_ROOT}/infra/terraform/sitl-key.pem"
CURRENT_IP=$(curl -s https://checkip.amazonaws.com)

# Display
echo "=========================================="
echo "  Cloud SITL Connection Details"
echo "=========================================="
echo ""
echo -e "${BLUE}Your current IP: $CURRENT_IP${NC}"
echo ""
echo "Connection Info:"
echo "  SITL_IP=${SITL_IP}"
echo "  SITL_CONNECTION=${SITL_CONNECTION}"
echo "  SSH_KEY=${SSH_KEY}"
echo ""

# Test SSH connectivity
echo "Testing SSH connection..."
if ssh -i "${SSH_KEY}" -o ConnectTimeout=5 -o StrictHostKeyChecking=no ubuntu@${SITL_IP} "echo 'connected'" 2>/dev/null | grep -q "connected"; then
    echo -e "${GREEN}✓ SSH connection OK${NC}"
else
    echo -e "${YELLOW}⚠ SSH connection failed${NC}"
    echo "  Your IP may have changed since the instance was created."
    echo ""
    echo "  To fix, run:"
    echo "    ./update-sg-ip.sh"
    echo ""
fi

echo "Quick Commands:"
echo "  # SSH to instance:"
echo "  ssh -i ${SSH_KEY} ubuntu@${SITL_IP}"
echo ""
echo "  # Connect with MAVProxy:"
echo "  mavproxy.py --master=${SITL_CONNECTION}"
echo ""
echo "  # Test with vehicle adapter:"
echo "  python3 -m adapters.vehicle_adapter --connection ${SITL_CONNECTION} --command arm"
echo ""
echo "  # Update security group (if your IP changed):"
echo "  ./update-sg-ip.sh"
echo ""

# Optionally export for use in current shell
if [ "$1" == "--export" ]; then
    echo "# Run this to export variables:"
    echo "export SITL_IP=${SITL_IP}"
    echo "export SITL_CONNECTION=${SITL_CONNECTION}"
    echo "export SSH_KEY=${SSH_KEY}"
fi
