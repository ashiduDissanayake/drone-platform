# Gazebo Integration for drone-platform

## Overview

3D visualization and physics simulation using Gazebo (Ignition/Gazebo Modern) with ArduPilot SITL.

## Architecture

```
[Mission Manager] --MAVLink--> [ArduPilot SITL] --JSON--> [Gazebo]
                                                    (physics + 3D viz)
```

## Quick Start

```bash
# Start Gazebo + ArduPilot SITL
cd simulation/gazebo
docker compose -f docker-compose.gazebo.yaml up

# In another terminal, run mission
python3 -m autonomy.mission_manager --deployment deployments/full_sitl__gazebo.yaml
```

## Components

### 1. Gazebo Simulator
- **Version**: Gazebo Harmonic (LTS) or Gazebo Garden
- **Physics**: DART or Bullet
- **Rendering**: Ogre2

### 2. ardupilot_gazebo Plugin
- Connects ArduPilot SITL to Gazebo physics
- Provides Iris quadcopter model
- Exposes MAVLink to mission manager

### 3. ArduPilot SITL
- Runs inside Docker container
- Connected to Gazebo for physics
- Exposes MAVLink on TCP port

## Connection Flow

1. Gazebo starts with `iris_runway` world
2. ardupilot_gazebo plugin loads Iris model
3. ArduPilot SITL connects to Gazebo via JSON socket
4. Mission manager connects to SITL via MAVLink (TCP)
5. Commands flow: Mission Manager → SITL → Gazebo → Physics

## Available Worlds

- `iris_runway` - Basic quadcopter with runway
- `iris_warehouse` - Indoor warehouse environment
- `iris_empty` - Empty world for custom scenarios

## Troubleshooting

### Gazebo doesn't show drone
- Check SITL is connected: `docker compose logs sitl`
- Verify plugin is loaded: `docker compose logs gazebo`

### Mission manager can't connect
- Check ports: `docker compose ps`
- Default MAVLink port: `tcp:127.0.0.1:5760`

