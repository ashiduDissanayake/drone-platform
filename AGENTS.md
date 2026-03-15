# drone-platform: Agent Guide

## Project Overview

**drone-platform** is an ArduPilot-first, modular, profile-driven, topology-aware drone platform monorepo. It provides a structured configuration model for deploying drone autonomy systems across various simulation and hardware configurations.

### V1 Focus
- Scope: Profile A (Full SITL), Profile C (Companion Hybrid)
- Autopilot default: ArduPilot SITL (kept behind the vehicle adapter boundary)
- Topologies: T1 (Single Device), T2 (Split Device)
- Scenario: takeoff -> waypoint -> land
- Constraint: multi-device deployment from day one (no localhost-only assumptions)

## Technology Stack

| Component | Technology |
|-----------|------------|
| Language | Python 3.10+ |
| Dev Environment | Nix with flakes |
| IaC | Ansible |
| Containers | Docker Compose |
| Config Format | YAML |
| CI/CD | GitHub Actions |
| Linting | yamllint |

### Dependencies
- `pyyaml` - YAML parsing (required for validation and runtime)
- `yamllint` - YAML linting
- Standard Python library (dataclasses, argparse, json, datetime)

## Project Structure

```
drone-platform/
├── adapters/           # Vehicle/world/telemetry integrations (stubs in V1)
│   ├── telemetry_adapter/
│   ├── vehicle_adapter/
│   └── world_adapter/
├── autonomy/           # Mission/business logic (stubbed in V1)
│   └── mission_manager/
├── deployments/        # Binds profile + topology + inventory
├── docs/               # Architecture docs, ADRs, onboarding guides
│   ├── adr/            # Architecture Decision Records
│   ├── architecture/   # Technical architecture documentation
│   └── onboarding/     # Getting started guides
├── infra/              # Infrastructure automation
│   ├── ansible/        # Provisioning and deployment
│   └── compose/        # Docker Compose configurations
├── interfaces/         # Stable contracts between autonomy and adapters
├── inventory/          # Defines available physical devices
├── missions/           # Mission scenario definitions
├── ops/scripts/        # Developer bootstrap and validation scripts
├── profiles/           # Defines what is simulated vs real
├── simulation/         # Simulation integration placeholders
├── topologies/         # Defines where services run by role
└── .github/workflows/  # CI scaffolding
```

## Configuration Model (V1)

The platform uses a four-layer configuration model:

1. **Profile** (`profiles/`): Defines simulated vs real components
   - `full_sitl.yaml`: Full Software-in-the-Loop simulation
   - `companion_hybrid.yaml`: Real vehicle with simulated world support

2. **Topology** (`topologies/`): Maps runtime roles to device roles
   - `single_device.yaml`: All roles on one device
   - `split_device.yaml`: Roles distributed across devices

3. **Inventory** (`inventory/`): Defines concrete physical devices and capabilities
   - `devices.example.yaml`: Example device definitions

4. **Deployment** (`deployments/`): Binds profile + topology + inventory
   - `full_sitl__single_device.yaml`: Full SITL on single device
   - `full_sitl__split_device.yaml`: Full SITL across multiple devices

### Resource Kinds

All configuration files use the `drone-platform/v1` API version with these `kind` values:
- `Profile` - Component simulation/real definitions
- `Topology` - Role placement definitions
- `Inventory` - Device inventory
- `Deployment` - Composition of the above
- `MissionScenario` - Mission action sequences

## Build and Development Commands

### Enter Development Shell
```bash
nix develop
```

The Nix shell includes: Python 3, Ansible, Docker Compose, yamllint, pre-commit, git, yq.

### Validate Configuration
```bash
# Validate all deployments
python3 ops/scripts/validate-config.py --all

# Validate specific deployment
python3 ops/scripts/validate-config.py --deployment deployments/full_sitl__single_device.yaml
```

### Run Mission Manager
```bash
# Single device deployment
python3 -m autonomy.mission_manager --deployment deployments/full_sitl__single_device.yaml

# With custom backend
python3 -m autonomy.mission_manager --deployment deployments/full_sitl__single_device.yaml --vehicle-backend ardupilot_sitl
```

### Run Vehicle Adapter (Standalone)
```bash
python3 -m adapters.vehicle_adapter --backend ardupilot_sitl --command takeoff --payload '{"vehicle_id": "v1", "target_altitude_m": 10}'
```

### Docker Compose
```bash
cd infra/compose/
docker compose -f docker-compose.base.yaml -f docker-compose.full_sitl__single_device.yaml up
```

### Bootstrap Helper
```bash
./ops/scripts/bootstrap-dev.sh
```

## Code Style Guidelines

### Python
- Use `from __future__ import annotations` for forward references
- Type hints are encouraged
- Docstrings for modules and public functions
- Error handling: print to stderr and return non-zero exit codes for CLI tools

### YAML
- Use `.yaml` extension consistently
- Line length maximum: 140 characters (configured in `.yamllint.yml`)
- Document start marker (`---`) is disabled
- Truthy values: use `true`/`false` or `on`/`off`
- Indent with 2 spaces

### Configuration File Structure
```yaml
apiVersion: drone-platform/v1
kind: <ResourceKind>
metadata:
  name: <name>
  description: "<description>"
spec:
  # Resource-specific spec
```

## Testing Instructions

### Lint Checks
```bash
# YAML linting
yamllint .

# Python syntax check
python3 -m py_compile ops/scripts/validate-config.py autonomy/mission_manager/main.py adapters/vehicle_adapter/main.py
```

### Configuration Validation
The `validate-config.py` script performs:
1. File existence checks
2. YAML parsing validation
3. Required field validation (profile, topology, inventory, role_assignments)
4. Cross-reference validation (ensures referenced files exist and have correct `kind`)
5. Role assignment consistency checks
6. Mission scenario reference validation

### CI Pipeline
GitHub Actions runs on pull requests:
1. **lint** job: YAML linting + Python syntax check
2. **config-validation** job: Runs `validate-config.py --all`

## Interface Contracts

### Vehicle Contract (V1)
Defines the interface between mission manager and vehicle adapter.

**Commands (mission manager -> vehicle adapter):**
- `arm` - payload: `{ "vehicle_id": "string" }`
- `disarm` - payload: `{ "vehicle_id": "string" }`
- `takeoff` - payload: `{ "vehicle_id": "string", "target_altitude_m": "number" }`
- `goto_waypoint` - payload: `{ "vehicle_id": "string", "lat": "number", "lon": "number", "alt": "number" }`
- `land` - payload: `{ "vehicle_id": "string" }`

**Telemetry outputs (vehicle adapter -> mission manager):**
- `position`: `{ "lat": "number", "lon": "number", "alt_m": "number" }`
- `velocity`: `{ "vx_mps": "number", "vy_mps": "number", "vz_mps": "number" }`
- `battery`: `{ "voltage_v": "number", "percent": "number" }`
- `state`: `{ "armed": "boolean", "mode": "string", "health_flags": "object" }`
- envelope: `{ "timestamp": "string", "vehicle_id": "string", "data": "object" }`

### Mission Contract (V1)
Mission scenario format consumed by mission manager.

```yaml
apiVersion: drone-platform/v1
kind: MissionScenario
metadata:
  name: <scenario_name>
spec:
  vehicle_id: <vehicle_id>
  actions:
    - action: <action_name>
      params: <action_params>
```

Rules:
- `actions` is an ordered list of high-level steps
- Each action is adapter-agnostic and maps to the vehicle contract
- V1 required scenario: `takeoff -> waypoint -> land`

### Telemetry Contract (V1)
Defines normalized telemetry stream.

Minimum payload:
- timestamp
- vehicle_id
- position (lat, lon, alt)
- attitude (roll, pitch, yaw)
- velocity (x, y, z)
- battery (voltage, percent)
- health flags

## Security Considerations

- No secrets should be committed to the repository
- Inventory files contain connection details (hosts, users) - use `.gitignore` for production inventories
- Vehicle adapter contracts should validate inputs before execution
- Distributed deployments require secure transport between components

## Deployment Process

1. **Prepare Inventory**: Copy `inventory/devices.example.yaml` and customize for your environment
2. **Select Profile**: Choose from `profiles/` based on simulation/hardware mix
3. **Select Topology**: Choose from `topologies/` based on deployment layout
4. **Create Deployment**: Create YAML in `deployments/` binding the above
5. **Validate**: Run `python3 ops/scripts/validate-config.py --all`
6. **Provision**: Use Ansible playbooks in `infra/ansible/`
7. **Deploy**: Use Docker Compose files in `infra/compose/`

## Architecture Decisions

Key ADRs recorded in `docs/adr/`:
- **ADR 0001**: Use a Monorepo - for simpler change coordination
- **ADR 0002**: Profile/Topology/Inventory/Deployment Model - for reproducible deployments
- **ADR 0003**: Multi-device-first design - no localhost-only assumptions
- **ADR 0004**: Nix + Ansible + Compose - for reproducible dev environments
- **ADR 0005**: Prefer ArduPilot as V1 autopilot backend

## V1 Scope

**In scope:**
- Monorepo bootstrap and directory structure
- Config model templates
- Interface contract placeholders
- Nix dev shell scaffold
- Ansible and Docker Compose skeleton
- Basic validation script and CI scaffolding

**Out of scope:**
- Full robotics stack packaging
- Production mission logic
- Perception pipelines
- Swarm and cloud backend complexity
