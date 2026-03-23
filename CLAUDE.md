# drone-platform — Agent Context Map

## Project Identity
ArduPilot-first autonomous drone simulation platform. **4-layer config model:**
**Profile** (what's simulated) → **Topology** (where services run) → **Inventory** (device IPs) → **Deployment** (binds all three).

**Platform vision:** Web-native GCS + simulation — ArduPilot SITL + Gazebo headless on EC2, full ROS2 integration, React UI with CesiumJS mission planner and Babylon.js simulation view, MQTT telemetry bus for multi-user support.

## Non-Negotiable Rules
1. Never bypass `adapters/vehicle_adapter/` — all MAVLink I/O flows through it.
2. No hardcoded IPs/ports — use only `interfaces/config.py` Pydantic models.
3. All logging via `interfaces.logging.get_logger()` — no `print()` or raw `logging`.
4. Config overrides via `DRONE__<SECTION>__<KEY>=value` env vars only.

## Key Components
| Component | Path | Status |
|---|---|---|
| Vehicle Adapter | `adapters/vehicle_adapter/main.py` | ✅ Production |
| Mission Manager | `autonomy/mission_manager/main.py` | ✅ Production |
| SITL Manager | `simulation/sitl_manager.py` | ✅ Production |
| Config (Pydantic) | `interfaces/config.py` | ✅ Production |
| Logging | `interfaces/logging.py` | ✅ Production |
| Gazebo Headless | `simulation/gazebo/` | ✅ EC2 loopback proven |
| ROS2 Integration | `ros2/` | 🔧 Sprint 1 Active |
| API Server | `api/` | 📋 Sprint 2 |
| React UI | `ui/` | 📋 Sprint 3 |

## Active Sprint
**Sprint 1 — ROS2 Foundation**
Goal: ArduPilot SITL + Gazebo headless on EC2, all drone state as ROS2 topics, rosbridge WebSocket bridge verified in browser.
→ `docs/active_sprints/sprint1_ros2/tasks.md`

## Wayfinding
| Need | Path |
|---|---|
| Sprint 1 tasks | `docs/active_sprints/sprint1_ros2/tasks.md` |
| Sprint 1 architecture | `docs/active_sprints/sprint1_ros2/plan.md` |
| Sprint 2 tasks | `docs/active_sprints/sprint2_api/tasks.md` |
| Sprint 3 tasks | `docs/active_sprints/sprint3_ui/tasks.md` |
| Config model deep-dive | `docs/adr/0002-config-model.md` |
| Cloud infra (Terraform) | `infra/terraform/` + `infra/ansible/` |
| EC2 IP | `infra/terraform/sitl-key.pem` + check Terraform state |
| Archived sprints | `docs/archive/` |

## Platform Architecture (Target)
```
EC2 (ap-south-1 Mumbai)
├── gz sim -s                ← Gazebo headless physics
├── arducopter --model JSON  ← SITL on loopback
├── mavros2                  ← ArduPilot → ROS2 topics
├── rosbridge_suite          ← ROS2 → WebSocket → browser
├── ros_gz_bridge            ← Gazebo sensors → ROS2
├── api/ (FastAPI)           ← REST commands + WebSocket telemetry
└── EMQX broker              ← MQTT pub/sub (multi-user telemetry)

Browser
└── ui/ (React)
    ├── CesiumJS             ← GPS-accurate mission planner
    ├── Babylon.js           ← 3D simulation view + camera feed
    └── MQTT.js              ← live telemetry subscription
```

## SSH to EC2
```bash
ssh -o ServerAliveInterval=30 -o ServerAliveCountMax=3 \
  -i infra/terraform/sitl-key.pem ubuntu@15.207.113.11
```

## Quick Commands
```bash
# SSH to EC2
ssh -i infra/terraform/sitl-key.pem ubuntu@15.207.113.11

# Validate config
python ops/scripts/validate-config.py

# Run mission (stub, no vehicle needed)
python -m autonomy.mission_manager \
  --deployment deployments/full_sitl__single_device.yaml \
  --vehicle-backend stub
```
