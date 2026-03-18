# drone-platform

ArduPilot-first, modular, profile-driven, topology-aware drone platform monorepo.

V1 focus:
- Scope: Profile A (Full SITL), Profile C (Companion Hybrid)
- Autopilot default: ArduPilot SITL (kept behind the vehicle adapter boundary)
- Topologies: T1 (Single Device), T2 (Split Device)
- Scenario: takeoff -> waypoint -> land
- Constraint: multi-device deployment from day one (no localhost-only assumptions)

## What's Working Now

✅ **Configuration Model** - Profile/Topology/Inventory/Deployment layers  
✅ **Structured Logging** - Tagged output `[timestamp] [component] [LEVEL] message key=value`  
✅ **ArduPilot SITL** - Docker-based simulation (no local install needed)  
✅ **MAVLink Integration** - Real protocol communication with vehicles  
✅ **Mission Manager** - Orchestrates takeoff → waypoint → land scenarios  

## Repository layout

- `docs/` Architecture docs, ADRs, onboarding guides, SITL quickstart.
- `profiles/` Defines what is simulated vs real.
- `topologies/` Defines where services run by role.
- `inventory/` Defines available physical devices.
- `deployments/` Binds profile + topology + inventory for a runnable selection.
- `interfaces/` Stable contracts between autonomy and adapters.
- `autonomy/` Mission/business logic.
- `adapters/` Vehicle/world/telemetry integrations with MAVLink support.
- `simulation/` SITL lifecycle management.
- `infra/ansible/` Provisioning and deployment automation.
- `infra/compose/` Container composition including ArduPilot SITL.
- `ops/scripts/` Developer bootstrap, SITL helper, and config validation.
- `.github/workflows/` CI scaffolding.

## V1 model

- `profile`: what is simulated vs real.
- `topology`: where roles run.
- `inventory`: what devices exist.
- `deployment`: chosen profile + topology + inventory combination.

## Quick Start

### Option 1: One-Command Cloud SITL (Recommended)

Deploy ArduPilot SITL on AWS with one command:

```bash
# Clone and enter repository
git clone <repo-url>
cd drone-platform

# One command sets up everything:
# - Dev environment (Python, Terraform, Ansible)
# - AWS infrastructure (EC2 instance)
# - ArduPilot SITL (built and running)
./quickstart.sh
```

**Requirements:**
- AWS account with credentials (`aws configure`)
- macOS or Linux

**What happens:**
1. Installs dependencies (Terraform, Ansible, Python packages)
2. Creates EC2 instance with security group
3. Builds ArduPilot SITL on the cloud instance
4. Generates config with dynamic IP
5. Shows you how to connect

### Option 2: Local Development (Nix)

Using Nix (fully reproducible environment):
```bash
nix --extra-experimental-features "nix-command flakes" develop

# Start local SITL
./ops/scripts/sitl.sh start

# Run mission
python3 -m autonomy.mission_manager \
  --deployment deployments/full_sitl__single_device.yaml \
  --vehicle-backend ardupilot_sitl
```

### Option 3: Local Development (Manual)

```bash
# Setup dev environment
./setup-dev-env.sh

# Activate virtual environment
source .venv/bin/activate

# Start local SITL
./ops/scripts/sitl.sh start

# Run mission
python3 -m autonomy.mission_manager \
  --deployment deployments/full_sitl__single_device.yaml \
  --vehicle-backend ardupilot_sitl
```

**Log output:**
```
[14:17:26.123] [mission-manager] [INFO] starting deployment=... backend=ardupilot_sitl
[14:17:26.456] [vehicle-adapter] [INFO] connected to vehicle system=1 component=1
[14:17:26.789] [mission-manager] [INFO] executing command step=1/5 command=arm
...
```

### 4. Stop SITL

Local:
```bash
./ops/scripts/sitl.sh stop
```

Cloud (Terraform):
```bash
cd infra/terraform
terraform destroy
```

---

## Reproducible Workspace

This project uses a **workspace pattern** for reproducibility:

### First Time Setup
```bash
./setup-dev-env.sh        # Installs all dependencies (Terraform, Ansible, Python, etc.)
                          # Creates .venv/ with isolated Python environment
                          # Checks and installs system packages if missing
```

### Reuse Existing Workspace
```bash
# Just activate the existing environment
source .venv/bin/activate

# Or use the wrapper (no need to remember activate)
./.env-activate python -m adapters.vehicle_adapter --help
```

### What's Installed (and Reused)

| Component | Location | Reused? |
|-----------|----------|---------|
| Python packages | `.venv/` | ✅ Yes, until you delete it |
| Terraform | System or Homebrew | ✅ Yes, if already installed |
| Ansible | `.venv/` | ✅ Yes, part of Python venv |
| AWS CLI | System or Homebrew | ✅ Yes, if already installed |

### Force Reinstall
```bash
./setup-dev-env.sh --force   # Deletes and recreates everything
```

## Development Commands

```bash
# Validate all configurations
python3 ops/scripts/validate-config.py --all

# Run with stub backend (no SITL needed)
python3 -m autonomy.mission_manager \
  --deployment deployments/full_sitl__single_device.yaml \
  --vehicle-backend stub

# Auto-start SITL as part of mission
python3 -m autonomy.mission_manager \
  --deployment deployments/full_sitl__single_device.yaml \
  --vehicle-backend ardupilot_sitl \
  --start-sitl

# Check SITL status
./ops/scripts/sitl.sh status

# View SITL logs
./ops/scripts/sitl.sh logs
```

## Roadmap

See `docs/roadmap-v1.md` for the full development plan:

1. ✅ **Real SITL Integration** - Connect to actual ArduPilot simulator
2. 🔄 **Split Device Deployment** - Distribute across multiple machines
3. ⏳ **Companion Hybrid** - Real vehicle + simulated world
4. ⏳ **Full Real Hardware** - Production deployment

## Status

V1 provides working SITL simulation with MAVLink integration. Core autonomy and adapters are functional for simulation scenarios.
