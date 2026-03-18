#!/bin/bash
# Cleanup script for failed deployments
# Destroys AWS infrastructure to stop charges
# Usage: ./cleanup-failed.sh [--yes]

set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT/infra/terraform"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "=========================================="
echo "  Cleanup Failed Deployment"
echo "=========================================="
echo ""

# Check if Terraform state exists
if [ ! -f "terraform.tfstate" ]; then
    echo -e "${YELLOW}No Terraform state found.${NC}"
    echo "Nothing to clean up."
    exit 0
fi

# Get current resources
echo -e "${BLUE}Current infrastructure:${NC}"
terraform state list 2>/dev/null || echo "  (Unable to list resources)"
echo ""

# Show costs warning
echo -e "${YELLOW}⚠️  AWS charges apply while resources are running!${NC}"
echo ""
echo "This will destroy:"
echo "  - EC2 instance (charged per hour)"
echo "  - Security group (free)"
echo "  - SSH key pair (free)"
echo ""

# Confirm unless --yes flag
if [ "$1" != "--yes" ]; then
    read -p "Are you sure you want to destroy? [y/N]: " confirm
    if [[ "$confirm" != [yY] && "$confirm" != [yY][eE][sS] ]]; then
        echo "Cancelled."
        exit 0
    fi
fi

# Destroy
echo ""
echo -e "${YELLOW}Destroying infrastructure...${NC}"
terraform destroy -auto-approve

# Cleanup local files
echo ""
echo -e "${YELLOW}Cleaning up local files...${NC}"
rm -f terraform.tfstate terraform.tfstate.backup .terraform.lock.hcl
rm -f sitl-key.pem
rm -rf .terraform

echo ""
echo "=========================================="
echo -e "${GREEN}  Cleanup Complete!${NC}"
echo "=========================================="
echo ""
echo -e "${GREEN}✓ AWS resources destroyed${NC}"
echo -e "${GREEN}✓ Local files cleaned${NC}"
echo ""
echo "To start fresh, run:"
echo "  ./quickstart.sh"
echo ""
