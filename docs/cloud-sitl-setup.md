# Cloud SITL Setup Guide

Run ArduPilot SITL on AWS/GCP and control it from your Mac.

## Quick Start

### 1. Create Cloud VM

**AWS EC2:**
- Instance: t3.medium (2 vCPU, 4GB RAM)
- OS: Ubuntu 22.04 LTS
- Storage: 20GB
- Security Group: Allow TCP 5760, UDP 14550 from your IP

**GCP Compute Engine:**
- Machine: e2-medium (2 vCPU, 4GB RAM)
- OS: Ubuntu 22.04 LTS
- Firewall: Allow TCP 5760, UDP 14550 from your IP

### 2. Setup SITL on Cloud

SSH into your VM and run:

```bash
# Copy cloud-init.sh to VM
scp infra/cloud/cloud-init.sh ubuntu@YOUR_VM_IP:~/

# SSH to VM
ssh ubuntu@YOUR_VM_IP

# Run setup
chmod +x cloud-init.sh
./cloud-init.sh
```

This takes ~15 minutes (installs deps + builds SITL).

### 3. Start SITL

```bash
# On cloud VM
chmod +x start-sitl.sh
./start-sitl.sh
```

You'll see:
```
Starting ArduPilot SITL on tcp:0.0.0.0:5760...
Waiting for GPS lock (takes ~30 seconds)...
```

Wait for: `GPS 3D fix OK` or similar message.

### 4. Test from Your Mac

```bash
cd drone-platform
source .venv/bin/activate

# Connect to cloud SITL
python3 -m autonomy.mission_manager \
  --deployment deployments/full_sitl__single_device.yaml \
  --vehicle-backend ardupilot_sitl \
  --connection tcp:YOUR_VM_IP:5760
```

**Expected:**
```
[vehicle-adapter] connected to vehicle system=1
[mission-manager] executing command step=1/5 command=arm
[mission-manager] telemetry received armed=true mode=GUIDED  <-- SUCCESS!
```

## Security Note

**DO NOT** expose port 5760 to the world! Only allow your IP:
- AWS: Security Group → Inbound Rules → My IP
- GCP: Firewall → Source IP filter

## Troubleshooting

### Connection refused
```bash
# On cloud VM, check if SITL is listening
nc -l 5760

# Check security group/firewall rules
```

### SITL won't arm
Wait for GPS lock (30-60 seconds after SITL starts).

### Build fails
Ensure you have at least 4GB RAM on the VM.

## Next: Split Device Topology

This cloud setup IS split device! Mission manager on Mac, SITL on cloud.

To make it official, we'll create:
- `deployments/full_sitl__cloud.yaml`
- Network tunnel for secure connection
- Automatic cloud provisioning
