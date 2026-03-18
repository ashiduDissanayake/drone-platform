# Repository Audit & Roadmap: Gazebo Integration + Config Management

**Date:** 2026-03-16  
**Current Status:** SITL working (cloud + local), mission_manager functional, GCS connects  
**Next Goal:** Gazebo 3D visualization with proper configuration management

---

## Part 1: What We've Actually Built

### Core Working Components

```
✅ WORKING:
├── adapters/vehicle_adapter/main.py    (620 lines, fully functional)
│   ├── MAVLinkConnection class         (connects to SITL/hardware)
│   ├── Commands: arm, disarm, takeoff, goto_waypoint, land, set_mode
│   ├── Telemetry: position, battery, GPS, state
│   └── Works with: ArduPilot SITL 4.8 (cloud & local)
│
├── autonomy/mission_manager/main.py    (269 lines, functional)
│   ├── Loads YAML mission scenarios
│   ├── Executes commands sequentially
│   └── Supports: stub, ardupilot_sitl, ardupilot_serial backends
│
├── simulation/sitl_manager.py          (376 lines, multiple modes)
│   ├── Modes: dronekit, docker, local, external
│   ├── Manages SITL lifecycle
│   └── Auto-start/stop capability
│
├── interfaces/logging.py               (structured logging)
│   └── Tagged format: [timestamp] [component] [LEVEL] message key=value
│
└── infra/terraform/ + infra/ansible/   (cloud infrastructure)
    └── AWS EC2 SITL deployment fully automated
```

### Configuration System (Current - SCATTERED)

```
❌ PROBLEMS:
├── Hardcoded IPs: DEFAULT_SITL_CONNECTION = "tcp:127.0.0.1:5760"
├── Command-line args override everything
├── Deployment YAMLs partially used but not consistently
└── No central config loader

FILES INVOLVED:
├── profiles/*.yaml                     (what's simulated vs real)
├── topologies/*.yaml                   (where services run)
├── inventory/*.yaml                    (device definitions)
├── deployments/*.yaml                  (binds above together)
└── missions/*.yaml                     (mission scenarios)
```

### Stub/Empty Components (Need Cleanup)

```
⚠️  MOSTLY EMPTY:
├── adapters/telemetry_adapter/main.py  (9 lines - just a stub)
├── adapters/world_adapter/main.py      (9 lines - just a stub)
├── adapters/__init__.py                (7 lines)
├── simulation/__init__.py              (7 lines)
├── autonomy/__init__.py                (0 lines)
└── interfaces/__init__.py              (3 lines)

⚠️  DUPLICATE FILES:
├── infra/compose/compose.base.yml      (498 bytes)
├── infra/compose/docker-compose.base.yaml (1987 bytes)
├── infra/compose/docker-compose.sitl.yaml (1511 bytes)
├── infra/compose/docker-compose.sitl-modern.yaml (813 bytes)
└── infra/compose/docker-compose.full_sitl__single_device.yaml (1029 bytes)
```

---

## Part 2: What to Remove / Clean Up

### Immediate Cleanup (Before Gazebo)

| Item | Action | Reason |
|------|--------|--------|
| `adapters/telemetry_adapter/` | Remove or implement | Currently 9-line stub, unused |
| `adapters/world_adapter/` | Remove or implement | Currently 9-line stub, unused |
| `infra/compose/compose.base.yml` | Remove | Duplicate of docker-compose.base.yaml |
| `infra/compose/docker-compose.sitl.yaml` | Consolidate | Multiple SITL compose files confusing |
| `infra/compose/docker-compose.sitl-modern.yaml` | Consolidate | Merge into one proper SITL compose |
| `config/generated/` | Add to .gitignore | Generated files shouldn't be committed |
| `__pycache__/` | Add to .gitignore | Python cache |
| `*.pyc` files | Remove | 20 compiled Python files present |

### Files to Keep (Working)

```
KEEP:
├── adapters/vehicle_adapter/main.py    (core functionality)
├── autonomy/mission_manager/main.py    (orchestration)
├── simulation/sitl_manager.py          (SITL lifecycle)
├── interfaces/logging.py               (logging infrastructure)
├── ops/scripts/validate-config.py      (CI validation)
├── infra/terraform/                    (cloud infra)
├── infra/ansible/                      (deployment)
├── All YAML configs in profiles/, topologies/, inventory/, deployments/
└── Documentation in docs/
```

---

## Part 3: Configuration Management Plan

### Research Summary: Best Practices 2024

**Options Evaluated:**
1. **Pydantic Settings** - Type-safe, env var integration, validation ✓ RECOMMENDED
2. **dynaconf** - More flexible, supports Vault/Redis (overkill for now)
3. **Simple TOML** - No validation, manual parsing (error-prone)

**Decision:** Use Pydantic Settings v2.12+

### Why Pydantic Settings

| Feature | Benefit |
|---------|---------|
| Type Safety | Validates config at load time |
| Environment Variables | `DRONE__VEHICLE__CONNECTION=tcp:...` overrides file |
| Nested Models | `config.vehicle.timeouts.arm = 60` |
| TOML Support | Human-readable config files |
| `.env` Support | Local development secrets |
| CLI Integration | `--vehicle.connection tcp:...` auto-generated |

### Proposed Config Structure

```
config/
├── settings.toml                       # Base defaults
├── settings.local.toml                 # Local overrides (gitignored)
├── settings.production.toml            # Production template
└── loader.py                           # Pydantic Settings loader

# OR per-environment:
config/
├── default.toml                        # Base settings
├── dev.toml                            # Development overrides
├── cloud.toml                          # Cloud SITL settings
└── loader.py
```

### Example Config (settings.toml)

```toml
[vehicle]
backend = "ardupilot_sitl"
connection_string = "tcp:127.0.0.1:5760"
force_arm = false

[vehicle.timeouts]
connection = 30.0
arming = 60.0
takeoff = 120.0
mission = 300.0

[simulation]
mode = "local"  # "local", "docker", "cloud"
sitl_version = "4.8"
vehicle_type = "copter"

[simulation.gazebo]
enabled = false
world = "basic_field"
model = "iris"
physics_rtf = 1.0  # Real-time factor

[logging]
level = "INFO"
format = "structured"

[mqtt]  # For split-device topology
enabled = false
host = "localhost"
port = 1883
```

### Migration Path

1. **Create** `interfaces/config.py` with Pydantic models
2. **Replace** hardcoded constants with config loader
3. **Update** CLI args to use config as fallback (not override)
4. **Document** all config options in `docs/configuration.md`

---

## Part 4: Gazebo Integration Research

### Architecture Options

```
OPTION A: Gazebo Classic (Gazebo 11)
├── Pros: Mature, lots of models, ardupilot_gazebo plugin stable
├── Cons: EOL (end of life), no new features
└── Status: Not recommended for new projects

OPTION B: Modern Gazebo (formerly Ignition)
├── Pros: Active development, better performance, modular
├── Cons: Plugin migration needed, fewer models
└── Status: RECOMMENDED - future-proof

OPTION C: Gazebo + SITL Bridge
├── Same as B but with explicit separation
└── Best for our multi-device architecture
```

### Recommended Architecture (Modern Gazebo)

```
┌─────────────────────────────────────────────────────────────┐
│                    Gazebo Simulation                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   Iris Drone │  │   World      │  │  Sensors     │      │
│  │   Model      │  │   (SDF)      │  │  (Camera,    │      │
│  │              │  │              │  │   Lidar)     │      │
│  └──────┬───────┘  └──────────────┘  └──────────────┘      │
│         │                                                   │
│  ┌──────▼──────────┐                                        │
│  │ ardupilot_gazebo│  Plugin sends state, receives motors   │
│  │   plugin        │                                        │
│  └──────┬──────────┘                                        │
└─────────┼───────────────────────────────────────────────────┘
          │ UDP (FDM Protocol)
┌─────────▼───────────────────────────────────────────────────┐
│              ArduPilot SITL (running separately)            │
│         (our existing cloud SITL or local SITL)             │
└─────────┬───────────────────────────────────────────────────┘
          │ MAVLink
┌─────────▼───────────────────────────────────────────────────┐
│              Our Platform (mission_manager, QGC)            │
└─────────────────────────────────────────────────────────────┘
```

### Key Findings

1. **ardupilot_gazebo plugin** is the standard
   - Repo: https://github.com/ArduPilot/ardupilot_gazebo
   - Works with Modern Gazebo (Ignition)
   - Uses FDM (Flight Dynamics Model) protocol over UDP

2. **Communication Flow**
   - Gazebo plugin reads drone state (pose, IMU) from simulation
   - Sends to ArduPilot SITL via UDP
   - ArduPilot computes motor commands
   - Sends back to Gazebo plugin
   - Plugin applies forces to joints

3. **Launch Sequence**
   ```bash
   # 1. Start Gazebo with drone model
   gz sim -v4 -r iris_runway.sdf
   
   # 2. Start ArduPilot SITL (connects to Gazebo)
   sim_vehicle.py -v ArduCopter --model=gz --console
   
   # 3. Connect QGC/mission_manager
   # (MAVLink from SITL as usual)
   ```

### Integration Approaches

| Approach | Complexity | Best For |
|----------|------------|----------|
| A: Docker Compose all-in-one | Low | Quick start, demos |
| B: Separate processes | Medium | Development, debugging |
| C: Cloud SITL + Local Gazebo | High | Realistic cloud-edge |

**Recommendation:** Start with A (Docker Compose), move to C for production.

---

## Part 5: Implementation Roadmap

### Phase 1: Repository Cleanup (1-2 days)

- [ ] Remove stub adapters or implement minimally
- [ ] Consolidate Docker Compose files
- [ ] Add proper .gitignore for generated files
- [ ] Create `config/` structure with Pydantic Settings
- [ ] Migrate hardcoded values to config

### Phase 2: Config Management Implementation (2-3 days)

- [ ] Create `interfaces/config.py` with Pydantic models
- [ ] Implement TOML loading with environment overrides
- [ ] Update vehicle_adapter to use config
- [ ] Update mission_manager to use config
- [ ] Document all config options

### Phase 3: Gazebo Integration - Docker (3-5 days)

- [ ] Create `simulation/gazebo/` directory
- [ ] Add ardupilot_gazebo plugin to Docker Compose
- [ ] Create basic world SDF
- [ ] Integrate with existing SITL container
- [ ] Test: See drone in 3D, execute mission

### Phase 4: Gazebo Integration - Cloud/Local Split (3-5 days)

- [ ] Research Gazebo cloud streaming (GZ_WEB, gz-launch)
- [ ] Set up Gazebo on EC2 with GPU
- [ ] Stream visualization to local browser
- [ ] Run mission_manager locally, SITL+Gazebo in cloud

### Phase 5: Documentation & Polish (2 days)

- [ ] Update AGENTS.md with Gazebo info
- [ ] Create `docs/gazebo-setup.md`
- [ ] Record demo video/GIF
- [ ] Final code review and cleanup

---

## Part 6: File-by-File Action Plan

### Files to Modify

| File | Action | Lines | Priority |
|------|--------|-------|----------|
| `adapters/vehicle_adapter/main.py` | Remove hardcoded defaults, use config | 620 | P1 |
| `autonomy/mission_manager/main.py` | Use config for connections | 269 | P1 |
| `simulation/sitl_manager.py` | Use config for paths/versions | 376 | P1 |
| `infra/compose/docker-compose.*.yaml` | Consolidate, add Gazebo | Multiple | P2 |
| `flake.nix` | Add Gazebo dependencies | - | P3 |

### Files to Create

| File | Purpose | Priority |
|------|---------|----------|
| `interfaces/config.py` | Pydantic Settings loader | P1 |
| `config/settings.toml` | Default configuration | P1 |
| `config/settings.cloud.toml` | Cloud SITL config | P1 |
| `simulation/gazebo/gz_bridge.py` | Gazebo-ArduPilot bridge | P2 |
| `simulation/gazebo/worlds/basic_field.sdf` | Basic test world | P2 |
| `docs/configuration.md` | Config documentation | P1 |
| `docs/gazebo-integration.md` | Gazebo setup guide | P3 |

### Files to Remove

| File | Reason |
|------|--------|
| `adapters/telemetry_adapter/` | Empty stub, not used |
| `adapters/world_adapter/` | Empty stub, not used |
| `infra/compose/compose.base.yml` | Duplicate |
| `config/generated/*` | Should be gitignored |
| `*.pyc` | Compiled Python |

---

## Summary: What to Do Right Now

### Immediate Actions (Today)

1. **Start Config Management**
   ```bash
   mkdir -p config
   cat > config/settings.toml << 'EOF'
   [vehicle]
   backend = "ardupilot_sitl"
   connection_string = "tcp:127.0.0.1:5760"
   EOF
   ```

2. **Clean Up Repository**
   ```bash
   rm -rf adapters/telemetry_adapter adapters/world_adapter
   rm infra/compose/compose.base.yml
   echo "config/generated/" >> .gitignore
   find . -name "*.pyc" -delete
   find . -name "__pycache__" -type d -exec rm -rf {} +
   ```

3. **Create Config Loader**
   - Implement Pydantic Settings in `interfaces/config.py`
   - Start with vehicle connection settings

### Next Steps (Tomorrow)

1. Refactor vehicle_adapter to use config
2. Test with cloud SITL
3. Start Gazebo Docker research

---

## Appendix: Gazebo Resources

- **ardupilot_gazebo repo**: https://github.com/ArduPilot/ardupilot_gazebo
- **Gazebo migration guide**: https://gazebosim.org/api/sim/8/ardupilot.html
- **Modern Gazebo docs**: https://gazebosim.org/docs
- **GZ_WEB for cloud**: https://github.com/gazebo-web/gzweb

---

*This document should be updated as implementation progresses.*
