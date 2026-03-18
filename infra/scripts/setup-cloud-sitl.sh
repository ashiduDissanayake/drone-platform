#!/bin/bash
# Complete cloud SITL setup pipeline with proper error handling
# Usage: ./setup-cloud-sitl.sh

set -e

echo "=========================================="
echo "  Drone Platform - Cloud SITL Setup"
echo "=========================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check bash version (need 4.0+ for associative arrays)
if [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
    echo -e "${YELLOW}Warning: Bash ${BASH_VERSION} detected. Using simplified status tracking.${NC}"
    USE_SIMPLE_STATUS=1
else
    USE_SIMPLE_STATUS=0
    # Only use associative arrays if bash 4.0+
    declare -A STEP_STATUS
    declare -A STEP_MESSAGES
fi

# Track step results (simple arrays for bash 3.2 compatibility)
STEP_NAMES=()
STEP_STATUSES=()
STEP_MSGS=()

current_step=0
total_steps=8

log_step() {
    current_step=$((current_step + 1))
    echo ""
    echo -e "${BLUE}[${current_step}/${total_steps}] $1${NC}"
}

mark_success() {
    STEP_NAMES+=("$1")
    STEP_STATUSES+=("SUCCESS")
    STEP_MSGS+=("$2")
    if [ "$USE_SIMPLE_STATUS" -eq 0 ]; then
        STEP_STATUS[$1]="SUCCESS"
        STEP_MESSAGES[$1]="$2"
    fi
    echo -e "${GREEN}✓ $2${NC}"
}

mark_failed() {
    STEP_NAMES+=("$1")
    STEP_STATUSES+=("FAILED")
    STEP_MSGS+=("$2")
    if [ "$USE_SIMPLE_STATUS" -eq 0 ]; then
        STEP_STATUS[$1]="FAILED"
        STEP_MESSAGES[$1]="$2"
    fi
    echo -e "${RED}✗ $2${NC}"
}

mark_warning() {
    STEP_NAMES+=("$1")
    STEP_STATUSES+=("WARNING")
    STEP_MSGS+=("$2")
    if [ "$USE_SIMPLE_STATUS" -eq 0 ]; then
        STEP_STATUS[$1]="WARNING"
        STEP_MESSAGES[$1]="$2"
    fi
    echo -e "${YELLOW}⚠ $2${NC}"
}

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

# Step 1: Clean up
log_step "Cleaning up any leftover resources..."
cd infra/terraform

CURRENT_DATE=$(date +%Y%m%d)
aws ec2 describe-key-pairs --query "KeyPairs[?contains(KeyName, 'drone-platform-sitl-${CURRENT_DATE}')].[KeyName]" --output text 2>/dev/null | while read -r key_name; do
    if [ -n "$key_name" ]; then
        echo "  Removing old key pair: $key_name"
        aws ec2 delete-key-pair --key-name "$key_name" 2>/dev/null || true
    fi
done

if [ -f "terraform.tfstate" ]; then
    echo "  Found existing Terraform state, cleaning up..."
    terraform destroy -auto-approve 2>/dev/null || true
    rm -f terraform.tfstate terraform.tfstate.backup .terraform.lock.hcl
    rm -rf .terraform
    echo "  ✓ Cleaned up existing state"
fi

if [ -f "sitl-key.pem" ]; then
    rm -f sitl-key.pem
fi

mark_success "cleanup" "Cleanup complete"

# Step 2: Terraform Apply
log_step "Creating infrastructure with Terraform..."

if ! command -v terraform &> /dev/null; then
    mark_failed "terraform" "terraform is not installed"
    exit 1
fi

terraform init
if terraform apply -auto-approve; then
    SITL_IP=$(terraform output -raw sitl_public_ip)
    SSH_KEY="${REPO_ROOT}/infra/terraform/sitl-key.pem"
    mark_success "infrastructure" "Infrastructure created (IP: ${SITL_IP})"
else
    mark_failed "infrastructure" "Terraform apply failed"
    exit 1
fi

# Get outputs
SITL_IP=$(terraform output -raw sitl_public_ip)
SSH_KEY="${REPO_ROOT}/infra/terraform/sitl-key.pem"

# Ensure SSH key has correct permissions
if [ -f "$SSH_KEY" ]; then
    chmod 600 "$SSH_KEY"
else
    echo -e "${RED}✗ SSH key not found at ${SSH_KEY}${NC}"
    exit 1
fi

# Step 3: Generate Config
log_step "Generating deployment config..."
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

mark_success "config" "Config generated (config/generated/cloud-deployment.yaml)"

# Step 4: Update Ansible Inventory
log_step "Updating Ansible inventory..."

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

mark_success "inventory" "Ansible inventory updated"

# Step 5: Update Security Group
log_step "Updating Security Group with current IP..."
if "${REPO_ROOT}/infra/scripts/update-sg-ip.sh" 2>/dev/null; then
    mark_success "security_group" "Security Group updated"
else
    mark_warning "security_group" "Security Group update failed (may still work)"
fi

# Step 6: Wait for EC2
log_step "Waiting for EC2 to be ready..."
echo "  (This may take 2-5 minutes for cloud-init to complete)"
echo "  Checking SSH connection to ${SITL_IP}..."

sleep 15

READY=false
for i in {1..60}; do
    if ssh -i "${SSH_KEY}" -o ConnectTimeout=5 -o StrictHostKeyChecking=no ubuntu@${SITL_IP} "echo 'ready'" 2>/dev/null | grep -q "ready"; then
        READY=true
        break
    fi
    echo -n "."
    sleep 5
done

if [ "$READY" = true ]; then
    mark_success "ec2_ready" "EC2 is ready"
else
    mark_failed "ec2_ready" "EC2 SSH timeout"
    EXIT_EARLY=true
fi

# Step 7: Run Ansible
log_step "Configuring SITL with Ansible..."

if ! command -v ansible-playbook &> /dev/null; then
    mark_failed "ansible" "ansible-playbook not found"
    EXIT_EARLY=true
else
    cd "$REPO_ROOT/infra/ansible"
    if ansible-playbook -i inventory/aws-generated.yml site.yml; then
        mark_success "ansible" "Ansible configuration complete"
    else
        mark_failed "ansible" "Ansible configuration failed"
        EXIT_EARLY=true
    fi
fi

# Step 8: Verify SITL is running
log_step "Verifying SITL is running..."

if [ -z "$EXIT_EARLY" ]; then
    sleep 5  # Give SITL time to start
    
    if ssh -i "${SSH_KEY}" -o StrictHostKeyChecking=no ubuntu@${SITL_IP} "sudo systemctl is-active ardupilot-sitl" 2>/dev/null | grep -q "active"; then
        # Test MAVLink connection
        if python3 -c "
import sys
sys.path.insert(0, '${REPO_ROOT}')
from pymavlink import mavutil
import time
try:
    master = mavutil.mavlink_connection('tcp:${SITL_IP}:5760', timeout=5)
    master.wait_heartbeat(timeout=5)
    print('MAVLink OK')
    master.close()
except Exception as e:
    print(f'Failed: {e}')
    sys.exit(1)
" 2>/dev/null | grep -q "MAVLink OK"; then
            mark_success "sitl_verify" "SITL is running and accepting MAVLink connections"
        else
            mark_warning "sitl_verify" "SITL service running but MAVLink not responding"
        fi
    else
        mark_failed "sitl_verify" "SITL service is not running"
    fi
else
    mark_failed "sitl_verify" "Skipped (previous failures)"
fi

# Final Summary
echo ""
echo "=========================================="
echo "  SETUP SUMMARY"
echo "=========================================="
echo ""

# Count results
SUCCESS_COUNT=0
FAILED_COUNT=0
WARNING_COUNT=0

# Use simple arrays for compatibility with bash 3.2
i=0
while [ $i -lt ${#STEP_NAMES[@]} ]; do
    step="${STEP_NAMES[$i]}"
    status="${STEP_STATUSES[$i]}"
    message="${STEP_MSGS[$i]}"
    
    case $status in
        SUCCESS)
            echo -e "${GREEN}✓${NC} ${step}: ${message}"
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
            ;;
        FAILED)
            echo -e "${RED}✗${NC} ${step}: ${message}"
            FAILED_COUNT=$((FAILED_COUNT + 1))
            ;;
        WARNING)
            echo -e "${YELLOW}⚠${NC} ${step}: ${message}"
            WARNING_COUNT=$((WARNING_COUNT + 1))
            ;;
        *)
            echo -e "  ${step}: ${status}"
            ;;
    esac
    i=$((i + 1))
done

echo ""
echo "------------------------------------------"
echo -e "Results: ${GREEN}${SUCCESS_COUNT} succeeded${NC}, ${RED}${FAILED_COUNT} failed${NC}, ${YELLOW}${WARNING_COUNT} warnings${NC}"
echo "------------------------------------------"
echo ""

# Connection info (if available)
if [ -n "$SITL_IP" ]; then
    echo "Connection Details:"
    echo "  MAVLink: tcp://${SITL_IP}:5760"
    echo "  SSH:     ssh -i ${SSH_KEY} ubuntu@${SITL_IP}"
    echo ""
fi

# Final status and next steps
if [ "$FAILED_COUNT" -eq 0 ] && [ "$WARNING_COUNT" -eq 0 ]; then
    echo -e "${GREEN}==========================================${NC}"
    echo -e "${GREEN}  ✓ SETUP COMPLETE - ALL CHECKS PASSED${NC}"
    echo -e "${GREEN}==========================================${NC}"
    echo ""
    echo "Usage:"
    echo "  python3 -m autonomy.mission_manager --deployment config/generated/cloud-deployment.yaml"
    echo ""
    exit 0
elif [ "$FAILED_COUNT" -eq 0 ]; then
    echo -e "${YELLOW}==========================================${NC}"
    echo -e "${YELLOW}  ⚠ SETUP COMPLETE WITH WARNINGS${NC}"
    echo -e "${YELLOW}==========================================${NC}"
    echo ""
    echo "You may be able to proceed, but check the warnings above."
    echo ""
    exit 0
else
    echo -e "${RED}==========================================${NC}"
    echo -e "${RED}  ✗ SETUP FAILED - ACTION REQUIRED${NC}"
    echo -e "${RED}==========================================${NC}"
    echo ""
    echo "The EC2 instance is still running and incurring charges."
    echo ""
    echo "Next steps:"
    echo ""
    echo "  1. Fix and retry Ansible:"
    echo "     cd infra/ansible"
    echo "     ansible-playbook -i inventory/aws-generated.yml site.yml"
    echo ""
    echo "  2. SSH to debug:"
    echo "     ssh -i ${SSH_KEY} ubuntu@${SITL_IP}"
    echo ""
    echo "  3. Destroy to stop charges:"
    echo "     cd infra/terraform && terraform destroy"
    echo ""
    exit 1
fi
