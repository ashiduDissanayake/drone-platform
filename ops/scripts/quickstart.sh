#!/bin/bash
# One-command quickstart for drone-platform
# Sets up dev environment and deploys cloud SITL
# Usage: ./quickstart.sh

set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "=========================================="
echo "  Drone Platform - Quickstart"
echo "=========================================="
echo ""

# Track overall status
OVERALL_STATUS=0

# Step 1: Setup dev environment
echo -e "${BLUE}[Step 1/3] Setting up development environment...${NC}"
if [ ! -d ".venv" ]; then
    if ./ops/scripts/setup-dev-env.sh; then
        echo -e "${GREEN}✓ Dev environment setup complete${NC}"
    else
        echo -e "${RED}✗ Dev environment setup failed${NC}"
        OVERALL_STATUS=1
    fi
else
    echo -e "${GREEN}✓ Dev environment already exists${NC}"
    echo "  (Use ./ops/scripts/setup-dev-env.sh --force to reinstall)"
fi

if [ $OVERALL_STATUS -ne 0 ]; then
    echo ""
    echo -e "${RED}==========================================${NC}"
    echo -e "${RED}  Quickstart Failed${NC}"
    echo -e "${RED}==========================================${NC}"
    exit 1
fi

# Step 2: Check AWS credentials
echo ""
echo -e "${BLUE}[Step 2/3] Checking AWS credentials...${NC}"

source .venv/bin/activate

if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}✗ AWS credentials not configured${NC}"
    echo ""
    echo "Please configure AWS credentials:"
    echo "  aws configure"
    echo ""
    echo "You need:"
    echo "  - AWS Access Key ID"
    echo "  - AWS Secret Access Key"
    echo "  - Default region (e.g., us-east-1)"
    echo ""
    echo "Get credentials from: https://console.aws.amazon.com/iam/home#/security_credentials"
    echo ""
    exit 1
else
    AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
    AWS_USER=$(aws sts get-caller-identity --query Arn --output text | cut -d'/' -f2)
    echo -e "${GREEN}✓ AWS credentials OK${NC}"
    echo "  Account: $AWS_ACCOUNT"
    echo "  User: $AWS_USER"
fi

# Step 3: Deploy cloud SITL
echo ""
echo -e "${BLUE}[Step 3/3] Deploying Cloud SITL...${NC}"
echo ""

cd infra/scripts
if ./setup-cloud-sitl.sh; then
    echo ""
    echo -e "${GREEN}==========================================${NC}"
    echo -e "${GREEN}  ✓ Quickstart Complete!${NC}"
    echo -e "${GREEN}==========================================${NC}"
    echo ""
    exit 0
else
    echo ""
    echo -e "${RED}==========================================${NC}"
    echo -e "${RED}  ✗ Quickstart Failed${NC}"
    echo -e "${RED}==========================================${NC}"
    echo ""
    echo "Check the output above for details."
    echo ""
    exit 1
fi
