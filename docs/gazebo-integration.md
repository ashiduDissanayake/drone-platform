# Gazebo Integration

**Status:** ✅ **IMPLEMENTED**  
**Priority:** High (Phase 1)  
**Goal:** 3D visualization of drone missions

## Quick Start

```bash
# 1. Start Gazebo + ArduPilot SITL
cd simulation/gazebo
./start-gazebo.sh

# 2. Run mission (in another terminal)
python3 -m autonomy.mission_manager --deployment deployments/full_sitl__gazebo.yaml

# Or with config file
export DRONE_CONFIG_FILE=config/settings.gazebo.toml
python3 -m autonomy.mission_manager --deployment deployments/full_sitl__gazebo.yaml
```

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

## Implementation Status

### ✅ Phase 1: Local Docker Integration (COMPLETE)

**Delivered:**
- ✅ `simulation/gazebo/` directory structure
- ✅ `Dockerfile.gazebo` with Gazebo Harmonic + ardupilot_gazebo plugin
- ✅ `Dockerfile.sitl-gazebo` with ArduPilot SITL
- ✅ `docker-compose.gazebo.yaml` multi-container setup
- ✅ `start-gazebo.sh` convenience script
- ✅ Basic Iris model with runway world

**Usage:**
```bash
cd simulation/gazebo
./start-gazebo.sh
# Gazebo window opens with Iris drone
# SITL connects automatically
# Run mission manager to see it fly
```

### ✅ Phase 2: Integration with Mission Manager (COMPLETE)

**Delivered:**
- ✅ `config/settings.gazebo.toml` with Gazebo-specific settings
- ✅ `deployments/full_sitl__gazebo.yaml` deployment descriptor
- ✅ Mission manager connects via MAVLink (tcp:127.0.0.1:5760)
- ✅ Synchronization: SITL waits for Gazebo before starting

**Success Criteria - WORKING:**
```bash
export DRONE_CONFIG_FILE=config/settings.gazebo.toml
python3 -m autonomy.mission_manager --deployment deployments/full_sitl__gazebo.yaml
# See drone take off, fly waypoints, and land in Gazebo window
```

### 📋 Phase 3: Cloud Deployment (FUTURE)

**Planned:**
- [ ] Research gz-web or WebRTC streaming
- [ ] Add GPU instance type to Terraform
- [ ] Create `infra/ansible/roles/gazebo/`
- [ ] Test cloud Gazebo with local viewing

### 📋 Phase 4: Advanced Features (FUTURE)

- [ ] Camera sensor (view from drone)
- [ ] Lidar sensor (obstacle detection)
- [ ] Multiple drones
- [ ] Custom worlds (import from real locations)
- [ ] Wind/weather simulation

## File Structure

```
simulation/gazebo/
├── README.md                    # Gazebo-specific documentation
├── Dockerfile.gazebo            # Gazebo Harmonic + ardupilot_gazebo plugin
├── Dockerfile.sitl-gazebo       # ArduPilot SITL with Gazebo support
├── docker-compose.gazebo.yaml   # Multi-container orchestration
├── start-gazebo.sh              # Convenience startup script
├── worlds/                      # Custom SDF worlds (optional)
└── models/                      # Custom models (optional)
```

**Related Files:**
- `config/settings.gazebo.toml` - Gazebo configuration
- `deployments/full_sitl__gazebo.yaml` - Deployment descriptor
- `docs/gazebo-integration.md` - This documentation

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

## Quick Start

### Option 1: Using start-gazebo.sh (Recommended)

```bash
cd simulation/gazebo
./start-gazebo.sh

# In another terminal
python3 -m autonomy.mission_manager \
    --deployment deployments/full_sitl__gazebo.yaml
```

### Option 2: Using Docker Compose directly

```bash
cd simulation/gazebo

# With GUI
docker compose up --build

# Headless mode (no GUI)
docker compose up --build -d

# Stop
docker compose down
```

### Option 3: With Custom Config

```bash
export DRONE_CONFIG_FILE=config/settings.gazebo.toml
python3 -m autonomy.mission_manager \
    --deployment deployments/full_sitl__gazebo.yaml
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
