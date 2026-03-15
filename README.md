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

### 1. Enter Development Shell

Using Nix (recommended):
```bash
nix --extra-experimental-features "nix-command flakes" develop
```

Or Python venv:
```bash
python3 -m venv .venv
source .venv/bin/activate
pip install pyyaml pymavlink pyserial
```

### 2. Start ArduPilot SITL

```bash
./ops/scripts/sitl.sh start
```

Wait for "SITL is ready!" message.

### 3. Run a Mission

```bash
python3 -m autonomy.mission_manager \
  --deployment deployments/full_sitl__single_device.yaml \
  --vehicle-backend ardupilot_sitl
```

You'll see tagged log output:
```
[14:17:26.123] [mission-manager] [INFO] starting deployment=... backend=ardupilot_sitl
[14:17:26.456] [vehicle-adapter] [INFO] connected to vehicle system=1 component=1
[14:17:26.789] [mission-manager] [INFO] executing command step=1/5 command=arm
...
```

### 4. Stop SITL

```bash
./ops/scripts/sitl.sh stop
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
