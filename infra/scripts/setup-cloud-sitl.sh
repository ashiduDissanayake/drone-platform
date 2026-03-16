#!/bin/bash
# Complete cloud SITL setup pipeline
# Usage: ./setup-cloud-sitl.sh

set -e

echo "=========================================="
echo "  Drone Platform - Cloud SITL Setup"
echo "=========================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

# Step 1: Clean up any leftover resources from previous failed runs
echo ""
echo -e "${YELLOW}[1/7] Cleaning up any leftover resources...${NC}"
cd infra/terraform

# Clean up old key pairs that might conflict
CURRENT_DATE=$(date +%Y%m%d)
aws ec2 describe-key-pairs --query "KeyPairs[?contains(KeyName, 'drone-platform-sitl-${CURRENT_DATE}')].[KeyName]" --output text 2>/dev/null | while read -r key_name; do
    if [ -n "$key_name" ]; then
        echo "  Removing old key pair: $key_name"
        aws ec2 delete-key-pair --key-name "$key_name" 2>/dev/null || true
    fi
done

# Clean up local Terraform files if they exist (fresh start)
if [ -f "terraform.tfstate" ]; then
    echo "  Found existing Terraform state, cleaning up..."
    # Try to destroy existing infrastructure gracefully
    terraform destroy -auto-approve 2>/dev/null || true
    # Remove state files for fresh start
    rm -f terraform.tfstate terraform.tfstate.backup .terraform.lock.hcl
    rm -rf .terraform
    echo "  ✓ Cleaned up existing state"
fi

# Remove old SSH key file if it exists
if [ -f "sitl-key.pem" ]; then
    echo "  Removing old SSH key file..."
    rm -f sitl-key.pem
fi

echo -e "${GREEN}✓ Cleanup complete${NC}"

# Step 2: Terraform Apply
echo ""
echo -e "${YELLOW}[2/7] Creating infrastructure with Terraform...${NC}"

if ! command -v terraform &> /dev/null; then
    echo -e "${RED}Error: terraform is not installed${NC}"
    echo "Install from: https://developer.hashicorp.com/terraform/downloads"
    exit 1
fi

terraform init
terraform apply -auto-approve

# Get outputs
SITL_IP=$(terraform output -raw sitl_public_ip)
SSH_KEY="${REPO_ROOT}/infra/terraform/sitl-key.pem"

echo -e "${GREEN}✓ Infrastructure created${NC}"
echo ""
echo "  Note: If this script fails, run ./cleanup-failed.sh to stop AWS charges"
echo "  SITL IP: ${SITL_IP}"
echo "  SSH Key: ${SSH_KEY}"

# Step 3: Generate Config
echo ""
echo -e "${YELLOW}[3/7] Generating deployment config...${NC}"
cd "$REPO_ROOT"

mkdir -p config/generated

cat > config/generated/cloud-deployment.yaml << EOF
# Auto-generated cloud deployment config
# Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
# SITL IP: ${SITL_IP}

apiVersion: drone-platform/v1
kind: Deployment
metadata:
  name: cloud_sitl__generated
  description: Auto-generated cloud SITL deployment
generated_by: infra/scripts/setup-cloud-sitl.sh
spec:
  profile: profiles/full_sitl.yaml
  topology: topologies/split_device.yaml
  inventory: inventory/cloud.yaml
  role_assignments:
    gcs_host: local-laptop
    companion_host: cloud-vm-companion
    sim_host: cloud-vm-sitl
  params:
    sitl_connection: "tcp:${SITL_IP}:5760"
    mission: v1_takeoff_waypoint_land
    generated: true
EOF

echo -e "${GREEN}✓ Config generated${NC}"
echo "  File: config/generated/cloud-deployment.yaml"

# Step 4: Update Ansible Inventory
echo ""
echo -e "${YELLOW}[4/7] Updating Ansible inventory...${NC}"

cat > infra/ansible/inventory/aws-generated.yml << EOF
# Auto-generated AWS inventory
# Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")

all:
  children:
    sim_host:
      hosts:
        sitl-aws:
          ansible_host: ${SITL_IP}
          ansible_user: ubuntu
          ansible_ssh_private_key_file: ${SSH_KEY}
          ansible_python_interpreter: /usr/bin/python3
          ansible_ssh_common_args: '-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
EOF

echo -e "${GREEN}✓ Ansible inventory updated${NC}"

# Step 5: Update Security Group with current IP
echo ""
echo -e "${YELLOW}[5/7] Updating Security Group with current IP...${NC}"
"${REPO_ROOT}/infra/scripts/update-sg-ip.sh" || echo "  (Continuing anyway...)"

# Step 6: Wait for EC2 to be ready
echo ""
echo -e "${YELLOW}[6/7] Waiting for EC2 to be ready...${NC}"
echo "  (This may take 2-5 minutes for cloud-init to complete)"
echo "  Checking SSH connection to ${SITL_IP}..."

sleep 15  # Initial wait for SSH to come up

READY=false
for i in {1..60}; do
    if ssh -i "${SSH_KEY}" -o ConnectTimeout=5 -o StrictHostKeyChecking=no ubuntu@${SITL_IP} "echo 'ready'" 2>/dev/null | grep -q "ready"; then
        READY=true
        echo ""
        echo -e "${GREEN}✓ EC2 is ready${NC}"
        break
    fi
    echo -n "."
    sleep 5
done

if [ "$READY" = false ]; then
    echo ""
    echo -e "${YELLOW}⚠ Timeout waiting for EC2, but it may still be ready${NC}"
    echo "  Continuing anyway..."
fi

# Step 7: Run Ansible
echo ""
echo -e "${YELLOW}[7/7] Configuring SITL with Ansible...${NC}"
cd "$REPO_ROOT/infra/ansible"

if ! command -v ansible-playbook &> /dev/null; then
    echo -e "${YELLOW}Warning: ansible-playbook not found, skipping Ansible setup${NC}"
    echo "  Install with: pip install ansible"
    echo "  Or manually configure SITL on the instance"
else
    if ! ansible-playbook -i inventory/aws-generated.yml site.yml; then
        echo ""
        echo -e "${RED}==========================================${NC}"
        echo -e "${RED}  Ansible configuration FAILED${NC}"
        echo -e "${RED}==========================================${NC}"
        echo ""
        echo -e "${YELLOW}The EC2 instance is still running.${NC}"
        echo "You have 3 options:"
        echo ""
        echo "  1. Retry Ansible (fix issue and retry):"
        echo "     cd infra/ansible && ansible-playbook -i inventory/aws-generated.yml site.yml"
        echo ""
        echo "  2. SSH to instance and debug manually:"
        echo "     ssh -i ${SSH_KEY} ubuntu@${SITL_IP}"
        echo ""
        echo "  3. Destroy infrastructure (stop charges):"
        echo "     cd infra/terraform && terraform destroy"
        echo ""
        exit 1
    fi
    echo -e "${GREEN}✓ Ansible configuration complete${NC}"
fi

# Summary
echo ""
echo "=========================================="
echo -e "${GREEN}  Cloud SITL Setup Complete!${NC}"
echo "=========================================="
echo ""
echo "Connection Details:"
echo "  MAVLink: tcp://${SITL_IP}:5760"
echo "  SSH:     ssh -i ${SSH_KEY} ubuntu@${SITL_IP}"
echo ""
echo "Generated Files:"
echo "  Config:    config/generated/cloud-deployment.yaml"
echo "  Inventory: infra/ansible/inventory/aws-generated.yml"
echo ""
echo "Usage Examples:"
echo "  # Using mission manager:"
echo "  python3 -m autonomy.mission_manager --deployment config/generated/cloud-deployment.yaml"
echo ""
echo "  # Using vehicle adapter directly:"
echo "  python3 -m adapters.vehicle_adapter \\"
echo "    --connection tcp:${SITL_IP}:5760 \\"
echo "    --command arm"
echo ""
echo "  # Using MAVProxy:"
echo "  mavproxy.py --master=tcp:${SITL_IP}:5760"
echo ""
echo "To destroy infrastructure:"
echo "  cd infra/terraform && terraform destroy"
echo ""
