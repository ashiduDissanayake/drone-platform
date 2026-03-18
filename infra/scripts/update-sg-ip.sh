#!/bin/bash
# Update security group with current IP address
# Usage: ./update-sg-ip.sh

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
echo "  Update Security Group IP"
echo "=========================================="
echo ""

# Get current IP
CURRENT_IP=$(curl -s https://checkip.amazonaws.com)
echo -e "${BLUE}Your current IP: $CURRENT_IP${NC}"

# Check if Terraform state exists
if [ ! -f "terraform.tfstate" ]; then
    echo -e "${RED}Error: No Terraform state found.${NC}"
    echo "Run ./quickstart.sh first to create infrastructure."
    exit 1
fi

# Get security group ID from Terraform state (most reliable)
SG_ID=$(terraform output -raw sitl_security_group 2>/dev/null || \
        terraform state show aws_security_group.sitl 2>/dev/null | grep "^id" | awk '{print $3}' | tr -d '"')

# Fallback: find by name prefix if Terraform state doesn't work
if [ -z "$SG_ID" ] || [ "$SG_ID" = "None" ]; then
    SG_ID=$(aws ec2 describe-security-groups \
        --filters "Name=group-name,Values=drone-platform-sitl-*" \
        --query 'SecurityGroups[0].GroupId' \
        --output text 2>/dev/null)
fi

if [ -z "$SG_ID" ] || [ "$SG_ID" = "None" ]; then
    echo -e "${RED}Error: Security group not found.${NC}"
    echo "Make sure you've run './quickstart.sh' or 'terraform apply' first."
    exit 1
fi

echo -e "${BLUE}Security Group: $SG_ID${NC}"

# Get current rules
echo ""
echo "Current SSH rules:"
aws ec2 describe-security-groups \
    --group-ids "$SG_ID" \
    --query 'SecurityGroups[0].IpPermissions[?FromPort==`22`].[IpRanges[*].CidrIp]' \
    --output table

# Revoke old SSH rules (optional - keep them for backup)
# Uncomment if you want to remove old IPs:
# echo ""
# echo -e "${YELLOW}Removing old SSH rules...${NC}"
# OLD_RULES=$(aws ec2 describe-security-groups \
#     --group-ids "$SG_ID" \
#     --query 'SecurityGroups[0].IpPermissions[?FromPort==`22`]' \
#     --output json)
# 
# if [ "$OLD_RULES" != "[]" ]; then
#     aws ec2 revoke-security-group-ingress \
#         --group-id "$SG_ID" \
#         --ip-permissions "$OLD_RULES" 2>/dev/null || true
# fi

# Add new rule
echo ""
echo -e "${YELLOW}Adding your current IP ($CURRENT_IP/32)...${NC}"

if aws ec2 authorize-security-group-ingress \
    --group-id "$SG_ID" \
    --protocol tcp \
    --port 22 \
    --cidr "$CURRENT_IP/32" 2>/dev/null; then
    echo -e "${GREEN}✓ SSH rule added for $CURRENT_IP/32${NC}"
else
    echo -e "${YELLOW}⚠ Rule for $CURRENT_IP/32 may already exist${NC}"
fi

# Also update MAVLink port (5760)
echo -e "${YELLOW}Adding MAVLink port rule...${NC}"
if aws ec2 authorize-security-group-ingress \
    --group-id "$SG_ID" \
    --protocol tcp \
    --port 5760 \
    --cidr "$CURRENT_IP/32" 2>/dev/null; then
    echo -e "${GREEN}✓ MAVLink rule added for $CURRENT_IP/32${NC}"
else
    echo -e "${YELLOW}⚠ Rule for $CURRENT_IP/32 may already exist${NC}"
fi

echo ""
echo "=========================================="
echo -e "${GREEN}  Security Group Updated!${NC}"
echo "=========================================="
echo ""
echo "Your IP $CURRENT_IP is now allowed for:"
echo "  - SSH (port 22)"
echo "  - MAVLink (port 5760)"
echo ""
echo "You can now connect to your EC2 instance."
echo ""

# Show connection info
echo ""
echo "Connection Details:"
echo "  SITL_IP: $(terraform output -raw sitl_public_ip 2>/dev/null)"
echo "  SSH Key: ${REPO_ROOT}/infra/terraform/sitl-key.pem"
echo ""
echo "Run './get-connection.sh' for full details and connection test"
