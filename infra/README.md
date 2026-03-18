# Drone Platform Infrastructure

Infrastructure as Code (IaC) for deploying ArduPilot SITL simulator on AWS cloud.

## ⚠️ Cost Warning

**AWS charges money while EC2 is running!**

| Component | Cost | When Charged |
|-----------|------|--------------|
| EC2 c7i-flex.large | ~$0.04/hour | While instance is running |
| Data transfer | ~$0.09/GB | Outbound traffic only |
| Storage | ~$0.08/GB/month | EBS volume |

**Estimated cost:** ~$0.04/hour (~$1/day if left running)

**Always destroy when done:**
```bash
./cleanup-failed.sh  # Or: cd infra/terraform && terraform destroy
```

**If setup fails,** the EC2 stays running. You have 3 options:
1. **Retry Ansible** - Fix issue and retry (keeps EC2)
2. **Debug manually** - SSH in and fix (keeps EC2)
3. **Destroy** - Stop charges immediately

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  Terraform (Create Infrastructure)                              │
│  ├── EC2 instance (Ubuntu 22.04)                                │
│  ├── Security group (ports 22, 5760, 14550)                     │
│  └── SSH key pair                                               │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  Ansible (Configure Software)                                   │
│  ├── Install dependencies (git, python3, build tools)           │
│  ├── Clone ArduPilot repository                                 │
│  ├── Build SITL binary (waf configure && waf copter)            │
│  ├── Create start scripts                                       │
│  └── Setup systemd service (auto-start SITL)                    │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  Running SITL                                                   │
│  └── tcp:EC2_IP:5760 ←── Your Mac (MAVProxy/Vehicle Adapter)    │
└─────────────────────────────────────────────────────────────────┘
```

## Why Both Tools?

| Tool | Purpose | When It Runs |
|------|---------|--------------|
| **Terraform** | Creates AWS resources (EC2, security groups, keys) | Once per environment |
| **Ansible** | Installs and configures software on the EC2 | After Terraform, or to update config |

## Quick Start (One Command)

The fastest way to get a cloud SITL running:

```bash
# One command does everything:
# - Creates EC2 with Terraform
# - Generates config with the dynamic IP
# - Configures SITL with Ansible
cd infra/scripts
./setup-cloud-sitl.sh
```

**Then connect using the generated config:**
```bash
# Using mission manager (recommended)
python3 -m autonomy.mission_manager \
  --deployment config/generated/cloud-deployment.yaml

# Or using vehicle adapter directly
python3 -m adapters.vehicle_adapter \
  --connection $(cd infra/terraform && terraform output -raw sitl_connection_string) \
  --command arm
```

---

## Manual Steps (If You Prefer)

### 1. Prerequisites

```bash
# Install Terraform (Mac)
brew install terraform

# Install Ansible (Mac)
brew install ansible

# Configure AWS credentials
aws configure
# Enter your AWS Access Key ID, Secret Access Key, region (us-east-1)
```

### 2. Deploy Infrastructure (Terraform)

```bash
cd infra/terraform

# Initialize Terraform
terraform init

# Preview what will be created
terraform plan

# Create the infrastructure
terraform apply

# Save outputs
terraform output sitl_public_ip
terraform output sitl_connection_string
```

**Outputs you'll get:**
- `sitl_public_ip` - EC2 instance IP address (dynamic)
- `sitl_connection_string` - MAVLink connection string (e.g., `tcp:54.x.x.x:5760`)
- `ssh_command` - SSH command to connect
- `sitl-key.pem` - SSH private key (saved automatically)

### 3. Get Connection Details (After Terraform)

```bash
# Quick helper script
cd infra/scripts
./get-connection.sh

# Or export variables for use in current shell
source ./get-connection.sh --export
```

### 4. Configure SITL (Ansible)

```bash
cd infra/ansible

# The setup-cloud-sitl.sh script already generated the inventory
# Or manually update inventory/aws.yml with the EC2 IP

# Run Ansible to install and configure ArduPilot
ansible-playbook -i inventory/aws-generated.yml site.yml

# This will:
# - Install all dependencies
# - Clone ArduPilot
# - Build SITL (takes 10-15 minutes)
# - Start SITL service
```

### 5. Connect from Your Mac

```bash
# Using MAVProxy
mavproxy.py --master=tcp:$(terraform -chdir=infra/terraform output -raw sitl_public_ip):5760

# Or using Vehicle Adapter
python -m adapters.vehicle_adapter \
  --backend ardupilot_sitl \
  --connection tcp:$(terraform -chdir=infra/terraform output -raw sitl_public_ip):5760 \
  --command arm
```

## Directory Structure

```
infra/
├── terraform/               # Infrastructure provisioning
│   ├── main.tf             # EC2, security groups, key pairs
│   ├── variables.tf        # Configurable variables
│   ├── user-data.sh        # Initial EC2 setup
│   ├── inventory.tpl       # Ansible inventory template
│   └── sitl-key.pem        # Generated SSH key (auto-created)
│
├── ansible/                 # Software configuration
│   ├── site.yml            # Main playbook
│   ├── inventory/
│   │   └── aws.yml         # Dynamic inventory for AWS
│   └── roles/
│       ├── simulator/      # ArduPilot SITL setup
│       │   └── tasks/main.yml
│       └── common/         # Common setup tasks
│
├── cloud/                   # Legacy scripts (for reference)
│   ├── cloud-init.sh       # Standalone setup script
│   └── start-sitl.sh       # Manual start script
│
└── compose/                 # Docker Compose (alternative)
    ├── Dockerfile.sitl
    └── docker-compose.sitl.yaml
```

## Management Commands

### Update SITL Configuration (re-run Ansible)

```bash
cd infra/ansible
ansible-playbook -i inventory/aws.yml site.yml
```

### SSH into EC2 Instance

```bash
ssh -i infra/terraform/sitl-key.pem ubuntu@$(terraform -chdir=infra/terraform output -raw sitl_public_ip)

# Check SITL status
sudo systemctl status ardupilot-sitl

# View SITL logs
sudo journalctl -u ardupilot-sitl -f
```

### Handle IP Address Changes

If your ISP changes your IP address (common with residential internet), you won't be able to SSH to the EC2 instance. **Don't destroy the instance!** Just update the security group:

```bash
# Update security group with your new IP
./update-sg-ip.sh

# Or using the full path
./infra/scripts/update-sg-ip.sh
```

This is much faster than recreating the instance (seconds vs 15+ minutes).

### Get Connection Info

```bash
# Show connection details and test connectivity
./get-connection.sh

# Export as environment variables
source ./get-connection.sh --export
```

### Destroy Infrastructure (when done)

```bash
cd infra/terraform
terraform destroy
```

**⚠️ Warning:** This deletes the EC2 instance and all data!

## Troubleshooting

### Terraform fails with "Unauthorized"

```bash
# Check AWS credentials
aws sts get-caller-identity

# If needed, reconfigure
aws configure
```

### Ansible fails with SSH timeout / Connection refused

**Most likely cause: Your IP address changed**

If you see:
```
ssh: connect to host x.x.x.x port 22: Operation timed out
```

Your ISP may have changed your IP. Fix it with:
```bash
./update-sg-ip.sh
```

Then retry:
```bash
# Wait for EC2 to finish booting (cloud-init takes ~2 minutes)
# Then retry Ansible
cd infra/ansible
ansible-playbook -i inventory/aws-generated.yml site.yml

# Or check if EC2 is ready
ssh -i infra/terraform/sitl-key.pem ubuntu@<IP> "echo 'Ready!'"
```

### Ansible/Setup Failed - What Now?

**If the setup script fails, the EC2 instance is still running (and charging money).**

**Check what failed:**
```bash
# View detailed error output
# The script will show the specific error

# Common failures:
# - SSH timeout (IP changed) → Run: ./update-sg-ip.sh
# - Ansible playbook failed → Fix issue, then retry
# - Network issues → Retry the script
```

**Your options:**

1. **Retry Ansible** (keep EC2, retry config):
```bash
cd infra/ansible
ansible-playbook -i inventory/aws-generated.yml site.yml
```

2. **Debug Manually** (keep EC2, SSH in):
```bash
ssh -i infra/terraform/sitl-key.pem ubuntu@$(terraform -chdir=infra/terraform output -raw sitl_public_ip)
# Then debug and fix manually
```

3. **Destroy Everything** (stop charges immediately):
```bash
./cleanup-failed.sh
# Or skip confirmation: ./cleanup-failed.sh --yes
```

### SITL won't start

```bash
# SSH into EC2 and check logs
ssh -i infra/terraform/sitl-key.pem ubuntu@<IP>
sudo journalctl -u ardupilot-sitl -n 50

# Try manual start
~/start-sitl.sh
```

## Cost Optimization

- **Instance Type:** `c7i-flex.large` (~$0.04/hour) - good for SITL
- **When not in use:** Run `terraform destroy` to avoid charges
- **Spot instances:** Can save ~70% cost for non-critical testing

## Security Notes

- Security group restricts port 5760 to YOUR IP only
- SSH key is generated per-deployment
- No sensitive data in Terraform state

## Alternative: Docker Compose

If you prefer local simulation:

```bash
cd infra/compose
docker-compose -f docker-compose.sitl.yaml up
```

See [compose/README.md](compose/README.md) for details.
