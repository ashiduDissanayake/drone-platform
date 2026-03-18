# Gazebo Integration Plan

**Status:** Planned  
**Priority:** High (Phase 2)  
**Goal:** 3D visualization of drone missions

---

## Overview

Integrate Gazebo (Modern/Ignition) with ArduPilot SITL for realistic 3D visualization. This enables:
- Visual confirmation of drone movements
- Camera/sensor simulation
- Physics-based validation
- Demo and presentation capabilities

## Architecture

### System Diagram

```
┌────────────────────────────────────────────────────────────────────┐
│                        Gazebo Simulation                           │
│  ┌─────────────────┐     ┌─────────────────┉──────────────────┐   │
│  │   World (SDF)   │     │          Iris Drone Model          │   │
│  │   - Terrain     │◄────┤  - Physics body                    │   │
│  │   - Obstacles   │     │  - 4 rotors with joints            │   │
│  │   - Landing pad │     │  - IMU sensor                      │   │
│  └─────────────────┘     │  - Camera (optional)               │   │
│                          └─────────────────┬───────────────────┘   │
│                                            │                       │
│                          ┌─────────────────▼───────────────────┐   │
│                          │   ardupilot_gazebo plugin           │   │
│                          │   (sends state, receives motor cmds)│   │
│                          └─────────────────┬───────────────────┘   │
└────────────────────────────────────────────┼───────────────────────┘
                                             │ UDP (FDM protocol)
┌────────────────────────────────────────────▼───────────────────────┐
│                    ArduPilot SITL                                  │
│   (Running separately - our existing cloud or local SITL)          │
│                                                                    │
│   • Autopilot logic (PID controllers, navigation)                  │
│   • MAVLink output (to QGC/mission_manager)                        │
│   • FDM input (from Gazebo)                                        │
└────────────────────────────┬───────────────────────────────────────┘
                             │ MAVLink (TCP/UDP)
┌────────────────────────────▼───────────────────────────────────────┐
│                    Ground Control                                  │
│   • QGroundControl (GUI)                                           │
│   • mission_manager (YAML missions)                                │
│   • Custom GCS                                                     │
└────────────────────────────────────────────────────────────────────┘
```

### Data Flow

1. **Gazebo → ArduPilot** (100+ Hz)
   - IMU data (acceleration, gyroscope)
   - GPS position
   - Vehicle attitude (quaternion)

2. **ArduPilot → Gazebo** (50+ Hz)
   - Motor PWM commands (4 channels for quadcopter)

3. **ArduPilot → GCS** (4 Hz)
   - MAVLink telemetry (position, battery, status)

## Implementation Approaches

### Approach A: Docker Compose (Recommended for Start)

**Components:**
- `gz-sim` container (Gazebo simulation)
- `ardupilot-sitl` container (ArduPilot with FDM bridge)
- `mavlink-router` container (optional, for multi-GCS)

**Pros:**
- Easy to start/stop
- Reproducible environment
- Works on cloud (with virtual display)

**Cons:**
- GPU passthrough complexity
- Slightly higher latency

**File:** `infra/compose/docker-compose.gazebo.yaml`

### Approach B: Native Installation

**Requirements:**
- Modern Gazebo (Ignition) installed
- ardupilot_gazebo plugin built
- ArduPilot SITL built from source

**Pros:**
- Lower latency
- GPU acceleration works natively
- Easier debugging

**Cons:**
- Complex setup
- Platform-specific

### Approach C: Cloud Gazebo + Local Viewer

**Architecture:**
- Gazebo runs on EC2 (with GPU)
- Scene streamed via WebRTC or gz-web
- User views in browser

**Pros:**
- Run heavy sim in cloud
- View on any device
- Scalable

**Cons:**
- Streaming latency
- Complex setup
- Bandwidth intensive

## Implementation Plan

### Phase 1: Local Docker Integration (Week 1)

**Tasks:**
- [ ] Create `simulation/gazebo/` directory
- [ ] Add `ardupilot_gazebo` plugin as Git submodule or Dockerfile
- [ ] Create `Dockerfile.gazebo` with gz-sim + plugin
- [ ] Create basic world SDF (`worlds/basic_field.sdf`)
- [ ] Create `docker-compose.gazebo.yaml`
- [ ] Test: `docker compose up` → see drone in Gazebo

**Success Criteria:**
```bash
cd infra/compose
docker compose -f docker-compose.gazebo.yaml up
# Gazebo window opens with Iris drone
# SITL connects automatically
# Can arm/takeoff via QGC
```

### Phase 2: Integration with Mission Manager (Week 2)

**Tasks:**
- [ ] Add `gazebo.enabled` to config
- [ ] Update `simulation/sitl_manager.py` to handle Gazebo mode
- [ ] Ensure mission_manager can trigger missions with Gazebo visual
- [ ] Add synchronization wait (Gazebo ready before SITL)

**Success Criteria:**
```bash
export DRONE_CONFIG_FILE=config/settings.gazebo.toml
python3 -m autonomy.mission_manager --deployment deployments/full_sitl__single_device.yaml
# See drone take off in Gazebo window
```

### Phase 3: Cloud Deployment (Week 3)

**Tasks:**
- [ ] Research gz-web or WebRTC streaming
- [ ] Add GPU instance type to Terraform
- [ ] Create `infra/ansible/roles/gazebo/`
- [ ] Test cloud Gazebo with local viewing

**Success Criteria:**
- Gazebo runs on EC2
- User can view in browser
- Full mission execution with visualization

### Phase 4: Advanced Features (Week 4+)

- [ ] Camera sensor (view from drone)
- [ ] Lidar sensor (obstacle detection)
- [ ] Multiple drones
- [ ] Custom worlds (import from real locations)
- [ ] Wind/weather simulation

## File Structure

```
simulation/gazebo/
├── README.md
├── Dockerfile
├── docker-compose.yaml
├── worlds/
│   ├── basic_field.sdf
│   ├── runway.sdf
│   └── warehouse.sdf
├── models/
│   └── iris_with_gimbal/
│       ├── model.sdf
│       └── model.config
└── plugins/
    └── ardupilot_gazebo/  # Git submodule or download
```

## Configuration

Add to `config/settings.toml`:

```toml
[simulation.gazebo]
enabled = true
world = "basic_field"
model = "iris"
physics_rtf = 1.0
gz_version = "modern"

[simulation.gazebo.display]
headless = false
width = 1920
height = 1080

[simulation.gazebo.camera]
enabled = true
publish_topic = "/camera"
```

## Resources

### ardupilot_gazebo Plugin
- **Repo:** https://github.com/ArduPilot/ardupilot_gazebo
- **Docs:** https://ardupilot.org/dev/docs/sitl-with-gazebo.html
- **Tutorial:** https://gazebosim.org/api/sim/8/ardupilot.html

### Modern Gazebo (Ignition)
- **Install:** https://gazebosim.org/docs
- **Tutorials:** https://gazebosim.org/docs/latest/tutorials

### Models
- **Iris:** https://github.com/PX4/PX4-SITL_gazebo-classic
- **Gazebo Models:** https://app.gazebosim.org/fuel

## Quick Start (Future)

```bash
# Start Gazebo + SITL + Mission Manager
docker compose -f infra/compose/docker-compose.gazebo.yaml up

# In another terminal
python3 -m autonomy.mission_manager \
    --deployment deployments/full_sitl__single_device.yaml

# Or with config file
export DRONE_CONFIG_FILE=config/settings.gazebo.toml
python3 -m autonomy.mission_manager \
    --deployment deployments/full_sitl__single_device.yaml
```

## Troubleshooting

### Gazebo won't start (headless server)

```bash
# Install virtual display
sudo apt-get install xvfb
export DISPLAY=:99
Xvfb :99 -screen 0 1024x768x16 &
```

### SITL can't connect to Gazebo

Check FDM port (default 9002):
```bash
# In SITL startup
sim_vehicle.py --model=gazebo --console

# Check Gazebo plugin is listening
netstat -uln | grep 9002
```

### Low frame rate

```toml
# config/settings.toml
[simulation.gazebo]
physics_rtf = 0.5  # Run at half real-time
```

## See Also

- `docs/configuration.md` - Config system
- `simulation/sitl_manager.py` - SITL lifecycle
- `docs/REPOSITORY_AUDIT_AND_ROADMAP.md` - Overall roadmap
