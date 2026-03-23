# drone-platform: Agent Guide

*Last updated: 2026-03-24 — Platform V1 reboot to web-native GCS architecture*

## Project Overview

**drone-platform** is an ArduPilot-first autonomous drone simulation platform.

**Vision:** Web-native GCS — ArduPilot SITL + Gazebo headless on EC2, full ROS2 integration, React UI with CesiumJS mission planner and Babylon.js simulation view, MQTT telemetry bus for multi-user support.

**What makes it different from competitors (QGroundControl, FlytBase, etc.):**
- The only open, ArduPilot-first platform with a web-native GCS
- ROS2-native — all drone state published as standard ROS2 topics
- Clean 4-layer config model (Profile / Topology / Inventory / Deployment)
- Built for developers, not just operators

---

## Current Sprint

**Sprint 1 — ROS2 Foundation** (`docs/active_sprints/sprint1_ros2/`)

ArduPilot SITL + Gazebo headless already running on EC2 (loopback, proven). This sprint adds the ROS2 layer: MAVROS2 + rosbridge_suite + Foxglove verification.

→ Start here: `docs/active_sprints/sprint1_ros2/tasks.md`

---

## Sprint Roadmap

| Sprint | Goal | Status |
|---|---|---|
| Sprint 1 — ROS2 Foundation | MAVROS2 + rosbridge on EC2, verified in Foxglove Studio | 🔧 Active |
| Sprint 2 — API + MQTT | FastAPI commands + EMQX multi-user telemetry | 📋 Planned |
| Sprint 3 — React UI | CesiumJS mission planner + Babylon.js sim view | 📋 Planned |
| Sprint 4 — Inspection | Camera feed, inspection mission, anomaly overlay | 📋 Planned |

---

## Non-Negotiable Rules

1. Never bypass `adapters/vehicle_adapter/` — all MAVLink I/O flows through it.
2. No hardcoded IPs/ports — use only `interfaces/config.py` Pydantic models.
3. All logging via `interfaces.logging.get_logger()` — no `print()` or raw `logging`.
4. Config overrides via `DRONE__<SECTION>__<KEY>=value` env vars only.
5. All sprint work tracked in `docs/active_sprints/<sprint>/tasks.md` — no freeform TODOs.

---

## Platform Architecture

```
EC2 (ap-south-1 Mumbai) — 15.207.113.11
├── gz sim -s                ← Gazebo headless physics (proven on loopback)
├── arducopter --model JSON  ← ArduPilot SITL (loopback, no packet loss)
├── mavproxy                 ← MAVLink relay (port 5760)
├── mavros2                  ← Sprint 1: ArduPilot → ROS2 topics
├── rosbridge_suite          ← Sprint 1: ROS2 → WebSocket → browser (port 9090)
├── ros_gz_bridge            ← Sprint 1: Gazebo sensors → ROS2
├── foxglove_bridge          ← Sprint 1: Foxglove Studio dev tool (port 8765)
├── EMQX broker              ← Sprint 2: MQTT pub/sub multi-user (port 8083)
└── api/ (FastAPI)           ← Sprint 2: REST commands + telemetry (port 8000)

Browser (anywhere)
└── ui/ (React)              ← Sprint 3
    ├── CesiumJS             ← GPS-accurate mission planner
    ├── Babylon.js           ← 3D simulation view + camera feed
    └── MQTT.js              ← live telemetry via EMQX WebSocket
```

---

## Key Components

| Component | Path | Status |
|---|---|---|
| Vehicle Adapter | `adapters/vehicle_adapter/main.py` | ✅ Production |
| Mission Manager | `autonomy/mission_manager/main.py` | ✅ Production |
| SITL Manager | `simulation/sitl_manager.py` | ✅ Production |
| Config (Pydantic) | `interfaces/config.py` | ✅ Production |
| Logging | `interfaces/logging.py` | ✅ Production |
| Gazebo Headless | `simulation/gazebo/` | ✅ EC2 loopback proven |
| ROS2 Integration | `ros2/` | 🔧 Sprint 1 |
| API Server | `api/` | 📋 Sprint 2 |
| React UI | `ui/` | 📋 Sprint 3 |

---

## Interface Contracts

These are the stable API boundaries. Do not bypass them.

**Vehicle Contract** (`interfaces/vehicle_contract.md`) — Commands:
- `arm`, `disarm`, `takeoff {target_altitude_m}`, `goto_waypoint {lat, lon, alt}`, `land`

**Telemetry Contract** (`interfaces/telemetry_contract.md`) — Telemetry fields:
- `position {lat, lon, alt_m}`, `velocity {vx, vy, vz}`, `battery {voltage_v, percent}`, `state {armed, mode, health_flags}`

**MQTT Topic Schema** (Sprint 2+):
- `drones/{vehicle_id}/telemetry` — QoS 0, 10Hz
- `drones/{vehicle_id}/mission/status` — QoS 1
- `drones/{vehicle_id}/alerts` — QoS 1

---

## Configuration System

Four-layer model. All config is Pydantic (`interfaces/config.py`).

| Layer | Path | Purpose |
|---|---|---|
| Profile | `profiles/` | What's simulated vs real |
| Topology | `topologies/` | Where services run |
| Inventory | `inventory/` | Device IPs |
| Deployment | `deployments/` | Binds all three |

Config files: `config/settings.toml` (local), `config/settings.cloud.toml` (EC2), `config/settings.web_platform.toml` (new — EC2 + MQTT + API).

Override any value: `DRONE__VEHICLE__CONNECTION_STRING=tcp:15.207.113.11:5760`

---

## EC2 Access

```bash
# SSH
ssh -o ServerAliveInterval=30 -o ServerAliveCountMax=3 \
  -i infra/terraform/sitl-key.pem ubuntu@15.207.113.11

# Key location
infra/terraform/sitl-key.pem
```

---

## Quick Commands

```bash
# Validate all deployments
python ops/scripts/validate-config.py --all

# Run mission stub (no vehicle needed — good for testing config)
python -m autonomy.mission_manager \
  --deployment deployments/full_sitl__single_device.yaml \
  --vehicle-backend stub

# Run mission against cloud SITL
DRONE_CONFIG_FILE=config/settings.cloud.toml \
python -m autonomy.mission_manager \
  --deployment deployments/full_sitl__cloud.yaml \
  --force-arm
```

---

## Repository Layout

```
drone-platform/
├── adapters/           ← Vehicle adapter (MAVLink)
├── autonomy/           ← Mission manager
├── simulation/         ← SITL lifecycle + Gazebo headless
├── interfaces/         ← Contracts + Pydantic config + logging
├── config/             ← TOML settings files
├── deployments/        ← Deployment manifests (Profile+Topology+Inventory)
├── profiles/           ← Profile definitions
├── topologies/         ← Topology definitions
├── inventory/          ← Device IP registry
├── missions/           ← Mission YAML scenarios
├── ros2/               ← Sprint 1: ROS2 launch files + config
├── api/                ← Sprint 2: FastAPI server
├── ui/                 ← Sprint 3: React app
├── infra/              ← Terraform + Ansible + Docker Compose
├── ops/scripts/        ← Dev tooling + validation
├── docs/
│   ├── active_sprints/ ← Current sprint docs (context/plan/tasks)
│   ├── archive/        ← Completed/abandoned sprints
│   ├── adr/            ← Architecture Decision Records
│   ├── architecture/   ← Technical architecture docs
│   └── onboarding/     ← Getting started guides
└── .github/workflows/  ← CI
```

---

## Phase Roadmap (Long-Term)

| Phase | Timeline | Goal |
|---|---|---|
| Phase 1 — Web Platform | Now | ROS2 + API + React UI (Sprints 1–3) |
| Phase 2 — Inspection | +2 months | Camera feed, inspection missions, anomaly detection |
| Phase 3 — Real Hardware | +4 months | HIL testing, Cube Orange / Pixhawk 6X support |
| Phase 4 — Path Planning | +8 months | OMPL (RRT*), obstacle avoidance (ESDF/Voxblox) |
| Phase 5 — Multi-Agent | +12 months | Swarm coordination, 10+ vehicles, Kubernetes SITL |

---

## Code Style

- Python: `from __future__ import annotations`, type hints, `get_logger()` for all logging
- YAML: `.yaml` extension, 2-space indent, no `---` document start marker, max 140 chars/line
- Config resource YAML format:
  ```yaml
  apiVersion: drone-platform/v1
  kind: <ResourceKind>
  metadata:
    name: <name>
    description: "<description>"
  spec:
    # resource-specific fields
  ```

---

## CI

GitHub Actions (`.github/workflows/`):
- **lint**: YAML (`yamllint`) + Python syntax
- **config-validation**: `validate-config.py --all`
