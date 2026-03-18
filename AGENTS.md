# drone-platform: Agent Guide

## Project Overview

**drone-platform** is an ArduPilot-first, modular, profile-driven, topology-aware drone platform monorepo. It provides a structured configuration model for deploying drone autonomy systems across various simulation and hardware configurations.

**Vision**: To be the **most usable** open-source drone autonomy platform for researchers and developers, supporting **everything autonomy** from simulation to real-world deployment.

### V1 Focus
- Scope: Profile A (Full SITL), Profile C (Companion Hybrid)
- Autopilot default: ArduPilot SITL (kept behind the vehicle adapter boundary)
- Topologies: T1 (Single Device), T2 (Split Device)
- Scenario: takeoff -> waypoint -> land
- Constraint: multi-device deployment from day one (no localhost-only assumptions)

---

## Strategic Roadmap

### Success Criteria ("Most Usable" Definition)

| Criterion | Target | Current Status |
|-----------|--------|----------------|
| **Time to First Mission** | < 15 minutes from clone | ~15 min (quickstart.sh works!) |
| **Setup Friction** | Single command | `./quickstart.sh` works but slow |
| **Abstraction Clarity** | Component substitution without cascade | ✅ Adapter pattern implemented |
| **Debugging Efficiency** | < 5 min fault isolation | ✅ Structured logging implemented |

### Phase-Based Development

#### Phase 1: Foundation Hardening (0-3 months) → **CURRENT FOCUS**

**Goal**: Transform from functional prototype to production-ready platform

| Milestone | Deliverable | Success Criteria | Status |
|-----------|-------------|------------------|--------|
| **T2 Topology MVP** | Split-device deployment | Mission manager on laptop, SITL on cloud working | ✅ **COMPLETE** |
| **Gazebo Integration** | 3D visualization in Docker | See drone fly in Gazebo with mission manager | 🚧 Planned |
| **Test Coverage** | Unit + integration tests | 60%+ line coverage, CI passing | 🚧 In Progress |
| **Documentation** | Complete API reference + tutorials | External user can complete without help | 🚧 In Progress |

**Technology Choices**:
- **T2 Communication**: MQTT (mosquitto) for simplicity → Linkerd later if needed
- **Simulator**: Gazebo Modern (Ignition) with ardupilot_gazebo plugin
- **Testing**: pytest + simulation-in-the-loop

#### Phase 2: Real Hardware Bridge (3-6 months)

**Goal**: First real-world flight with complete platform stack

| Milestone | Deliverable | Success Criteria |
|-----------|-------------|------------------|
| **HIL Framework** | Hardware-in-the-loop testing | Deterministic behavior matching SITL within 5% |
| **Profile C** | Companion hybrid validation | Physical flight controller + simulated companion |
| **Safety Monitoring** | Independent failsafe system | 100% successful intervention in fault scenarios |
| **Hardware Support** | Cube Orange, Pixhawk 6X, Matek H743 | Same autonomy code works across targets |

#### Phase 3: Autonomy Expansion (6-12 months)

**Goal**: Capability parity with AUSPEX/Aerostack2

| Capability | Implementation | Validation Target |
|------------|---------------|-------------------|
| **Path Planning** | OMPL integration (RRT*, BIT*) | Success rate across obstacle density |
| **Obstacle Avoidance** | ESDF-based local planning (Voxblox) | Zero collisions at 3 m/s |
| **Visual Odometry** | VINS-Fusion or ORB-SLAM3 | < 1% drift over 100m |
| **MPC Control** | ACADO/CasADi trajectory optimization | < 20 cm tracking error |

#### Phase 4: Multi-Agent & Cloud Scale (12-18 months)

**Goal**: Swarm coordination with 10+ vehicles

- Distributed consensus (Raft/PBFT adaptation)
- Cloud orchestration (Kubernetes-based, 1000 concurrent SITL)
- Fleet management dashboard
- ROS2 Nav2 integration

#### Phase 5: Ecosystem & Standards (18-24 months)

**Goal**: Industry recognition as reference research platform

- Benchmark publication (IEEE T-RO or ICRA)
- Educational program (5+ university adoptions)
- Foundation governance structure
- Sustainable commercial support

---

## Technology Stack

| Component | Technology |
|-----------|------------|
| Language | Python 3.10+ |
| Dev Environment | Nix with flakes |
| IaC | Ansible |
| Containers | Docker Compose |
| Config Format | YAML + TOML |
| CI/CD | GitHub Actions |
| Linting | yamllint |

### Dependencies
- `pyyaml` - YAML parsing
- `yamllint` - YAML linting
- `pydantic-settings` - Type-safe configuration
- `pymavlink` - MAVLink protocol
- Standard Python library

---

## Project Structure

```
drone-platform/
├── adapters/           # Vehicle adapter (MAVLink integration - WORKING)
│   └── vehicle_adapter/
├── autonomy/           # Mission manager (WORKING)
│   └── mission_manager/
├── config/             # Configuration files (TOML)
│   ├── settings.toml           # Default local config
│   ├── settings.cloud.toml     # Cloud SITL config
│   └── settings.gazebo.toml    # Gazebo integration config
├── deployments/        # Binds profile + topology + inventory
├── docs/               # Architecture docs, ADRs, onboarding guides
│   ├── adr/            # Architecture Decision Records
│   ├── architecture/   # Technical architecture documentation
│   ├── configuration.md        # Config management guide
│   ├── gazebo-integration.md   # Gazebo setup guide
│   ├── roadmap-v1.md           # Detailed roadmap
│   └── onboarding/     # Getting started guides
├── infra/              # Infrastructure automation
│   ├── ansible/        # Provisioning and deployment
│   ├── compose/        # Docker Compose configurations
│   └── terraform/      # AWS infrastructure (cloud SITL)
├── interfaces/         # Stable contracts between components
│   ├── config.py       # Pydantic Settings configuration
│   └── logging.py      # Structured logging
├── inventory/          # Device inventory
├── missions/           # Mission scenario definitions
├── ops/scripts/        # Developer bootstrap and validation scripts
├── profiles/           # Component simulation/real definitions
├── simulation/         # SITL lifecycle manager (WORKING)
│   ├── sitl_manager.py
│   └── gazebo/         # Gazebo integration (Phase 1)
├── topologies/         # Service distribution definitions
└── .github/workflows/  # CI scaffolding
```

---

## Configuration Model

### Four-Layer Architecture

1. **Profile** (`profiles/`): Defines simulated vs real components
   - `full_sitl.yaml`: Full Software-in-the-Loop simulation
   - `companion_hybrid.yaml`: Real vehicle with simulated world

2. **Topology** (`topologies/`): Maps runtime roles to device roles
   - `single_device.yaml`: All roles on one device (T1)
   - `split_device.yaml`: Roles distributed across devices (T2)

3. **Inventory** (`inventory/`): Device definitions
   - `devices.example.yaml`: Example definitions
   - `cloud.yaml`: AWS EC2 inventory

4. **Deployment** (`deployments/`): Composition of above
   - `full_sitl__single_device.yaml`: Single device deployment
   - `full_sitl__cloud.yaml`: Cloud SITL deployment

### Resource Kinds

- `Profile` - Simulation/hardware definitions
- `Topology` - Role placement
- `Inventory` - Device catalog
- `Deployment` - Composition
- `MissionScenario` - Action sequences

---

## Build and Development Commands

### Enter Development Shell
```bash
nix develop
```

### Validate Configuration
```bash
# Validate all deployments
python3 ops/scripts/validate-config.py --all

# Validate specific deployment
python3 ops/scripts/validate-config.py --deployment deployments/full_sitl__single_device.yaml
```

### Run Mission Manager
```bash
# Local SITL (requires SITL running)
python3 -m autonomy.mission_manager --deployment deployments/full_sitl__single_device.yaml

# Cloud SITL (auto-connects to AWS)
export DRONE_CONFIG_FILE=config/settings.cloud.toml
python3 -m autonomy.mission_manager --deployment config/generated/cloud-deployment.yaml

# Gazebo (Phase 1)
export DRONE_CONFIG_FILE=config/settings.gazebo.toml
python3 -m autonomy.mission_manager --deployment deployments/full_sitl__gazebo.yaml
```

### Run Vehicle Adapter (Standalone)
```bash
python3 -m adapters.vehicle_adapter \
  --backend ardupilot_sitl \
  --command takeoff \
  --payload '{"vehicle_id": "v1", "target_altitude_m": 10}'
```

### Docker Compose
```bash
cd infra/compose/
docker compose -f docker-compose.base.yaml -f docker-compose.full_sitl__single_device.yaml up
```

### Bootstrap Helper
```bash
./quickstart.sh  # Full cloud setup
```

---

## Current Implementation Status

### ✅ Working Components (V1 Complete)

| Component | Status | Notes |
|-----------|--------|-------|
| `adapters/vehicle_adapter` | ✅ Complete | MAVLink integration, arm/takeoff/goto/land/disarm |
| `autonomy/mission_manager` | ✅ Complete | Sequential mission execution |
| `simulation/sitl_manager` | ✅ Complete | Local, Docker, Cloud SITL modes |
| `interfaces/logging` | ✅ Complete | Structured tagged logging |
| `interfaces/config` | ✅ Complete | Pydantic Settings, TOML + env overrides |
| Cloud SITL (AWS) | ✅ Complete | Terraform + Ansible automation |
| `infra/terraform` | ✅ Complete | EC2 SITL deployment |
| `infra/ansible` | ✅ Complete | SITL provisioning with MAVProxy GCS heartbeat |

### 🚧 Phase 1: Foundation Hardening (In Progress)

| Component | Target | Priority |
|-----------|--------|----------|
| **T2 Topology (MQTT)** | Mission manager ↔ SITL over network | **Critical** |
| **Gazebo Integration** | 3D visualization + physics | **High** |
| **Test Coverage** | 60%+ line coverage, CI passing | **High** |
| **Documentation** | API reference + tutorials | **Medium** |

### 📋 Phase 2-5: Planned

See **Strategic Roadmap** section above for Phase 2-5 milestones.

### ❌ Removed/Deferred

| Component | Decision | Rationale |
|-----------|----------|-----------|
| `telemetry_adapter` | ❌ Removed | Not needed for V1 |
| `world_adapter` | ❌ Removed | Not needed for V1 |
| Companion Hybrid Profile | ⏸️ Deferred | Phase 2 |
| Multi-agent Swarm | ⏸️ Deferred | Phase 4 |

---

## Configuration Usage

### Using Config Files
```bash
# Default (local development)
python3 -m autonomy.mission_manager --deployment deployments/full_sitl__single_device.yaml

# Cloud SITL
export DRONE_CONFIG_FILE=config/settings.cloud.toml
python3 -m autonomy.mission_manager --deployment deployments/full_sitl__cloud.yaml

# Or override with environment
export DRONE__VEHICLE__CONNECTION_STRING="tcp:3.95.154.113:5760"
export DRONE__VEHICLE__FORCE_ARM="true"
```

See `docs/configuration.md` for full details.

---

## Code Style Guidelines

### Python
- Use `from __future__ import annotations`
- Type hints encouraged
- Docstrings for modules and public functions
- Error handling: print to stderr, return non-zero exit codes

### YAML
- Use `.yaml` extension
- Max 140 characters per line (see `.yamllint.yml`)
- No document start marker (`---`)
- Indent with 2 spaces

### Configuration Structure
```yaml
apiVersion: drone-platform/v1
kind: <ResourceKind>
metadata:
  name: <name>
  description: "<description>"
spec:
  # Resource-specific spec
```

---

## Testing & CI

### Lint Checks
```bash
yamllint .
python3 -m py_compile ops/scripts/validate-config.py autonomy/mission_manager/main.py
```

### Configuration Validation
`validate-config.py` performs:
1. File existence checks
2. YAML parsing validation
3. Required field validation
4. Cross-reference validation
5. Role assignment consistency

### CI Pipeline
GitHub Actions runs on PRs:
1. **lint**: YAML + Python syntax
2. **config-validation**: `validate-config.py --all`

---

## Interface Contracts

### Vehicle Contract (V1)

**Commands:**
- `arm` - `{ "vehicle_id": "string" }`
- `disarm` - `{ "vehicle_id": "string" }`
- `takeoff` - `{ "vehicle_id": "string", "target_altitude_m": number }`
- `goto_waypoint` - `{ "vehicle_id": "string", "lat": number, "lon": number, "alt": number }`
- `land` - `{ "vehicle_id": "string" }`

**Telemetry:**
- `position`: `{ lat, lon, alt_m }`
- `velocity`: `{ vx_mps, vy_mps, vz_mps }`
- `battery`: `{ voltage_v, percent }`
- `state`: `{ armed, mode, health_flags }`

### Mission Contract (V1)
```yaml
apiVersion: drone-platform/v1
kind: MissionScenario
metadata:
  name: <name>
spec:
  vehicle_id: <id>
  actions:
    - action: <name>
      params: <params>
```

---

## Immediate Priorities (Next 2 Weeks)

Based on current state, focus on:

### ✅ Completed This Week
1. **Cloud SITL Pipeline** - Fully working end-to-end
   - Terraform infrastructure automation
   - Ansible provisioning with MAVProxy GCS heartbeat
   - Mission manager connects from laptop to Cloud SITL
   - Vehicle arms, takes off, executes waypoints, lands

### 🚧 Next Priority: Gazebo Integration (Week 1-2)

**Why Gazebo now?**
- Core platform (mission manager + vehicle adapter) is stable
- Cloud SITL proves distributed topology works
- Gazebo adds visual feedback and physics validation
- Natural progression before hardware (HIL)

**Deliverables:**
1. `simulation/gazebo/` directory with Docker Compose
2. ardupilot_gazebo plugin integration
3. Basic world (iris quadcopter + empty field)
4. Mission execution with 3D visualization
5. Documentation update

**Alternative priorities** (if Gazebo is not urgent):
- **MQTT-based T2**: Formalize split-device communication
- **Test Coverage**: Add pytest + integration tests
- **HIL Prep**: Prepare for hardware-in-the-loop

See `docs/roadmap-v1.md` for detailed Phase 1 plan.

---

## Security Considerations

- No secrets in repository
- Inventory files in `.gitignore` for production
- Input validation in vehicle adapter
- Secure transport for distributed deployments (mTLS in Phase 1)

---

## Architecture Decisions

Key ADRs in `docs/adr/`:
- **ADR 0001**: Monorepo structure
- **ADR 0002**: Profile/Topology/Inventory/Deployment model
- **ADR 0003**: Multi-device-first design
- **ADR 0004**: Nix + Ansible + Compose
- **ADR 0005**: ArduPilot-first backend

---

## Contributing

1. Check **Current Implementation Status** above
2. Pick from **Phase 1: Foundation Hardening** tasks
3. See `docs/onboarding/` for setup guides
4. Follow code style guidelines
5. Add tests for new features

---

*Last updated: 2026-03-18*
*Current Phase: Phase 1 - Foundation Hardening (Cloud SITL Complete)*
