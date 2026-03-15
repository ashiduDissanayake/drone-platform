# ArduPilot SITL Quick Start

This guide gets you running real ArduPilot SITL simulation without installing anything on your host machine (except Docker).

## Prerequisites

- Docker and Docker Compose installed
- Python 3.10+ with virtual environment

## Setup

### 1. Enter Development Environment

Using Nix (recommended):
```bash
nix --extra-experimental-features "nix-command flakes" develop
```

Or using Python venv:
```bash
python3 -m venv .venv
source .venv/bin/activate
pip install pyyaml pymavlink pyserial
```

### 2. Start SITL

Option A: Using the helper script:
```bash
./ops/scripts/sitl.sh start
```

Option B: Using Docker Compose directly:
```bash
docker compose -f infra/compose/docker-compose.sitl.yaml up -d
```

Wait for SITL to be ready (you'll see "SITL is ready!" message).

### 3. Check SITL Status

```bash
./ops/scripts/sitl.sh status
```

You should see:
```
[INFO] SITL is running
[INFO]   Connection: tcp:127.0.0.1:5760
[INFO]   MAVLink UDP: udp:127.0.0.1:14550
```

### 4. Run Mission with Real SITL

```bash
python3 -m autonomy.mission_manager \
  --deployment deployments/full_sitl__single_device.yaml \
  --vehicle-backend ardupilot_sitl
```

Or auto-start SITL:
```bash
python3 -m autonomy.mission_manager \
  --deployment deployments/full_sitl__single_device.yaml \
  --vehicle-backend ardupilot_sitl \
  --start-sitl
```

### 5. View SITL Logs

```bash
./ops/scripts/sitl.sh logs
```

### 6. Stop SITL

```bash
./ops/scripts/sitl.sh stop
```

## What Happens During a Mission

1. **SITL Starts** → ArduPilot simulator boots with Copter firmware
2. **Mission Manager** connects via MAVLink (TCP port 5760)
3. **Commands Executed**:
   - `arm` → SITL arms the virtual motors
   - `takeoff 10` → Virtual drone climbs to 10m
   - `goto_waypoint` → Drone flies to coordinates
   - `land` → Drone descends and lands
   - `disarm` → Motors stop
4. **Telemetry** flows back with real position, battery, state

## Connection Strings

| Mode | Connection String | Use Case |
|------|------------------|----------|
| Docker SITL | `tcp:127.0.0.1:5760` | Default for docker-compose.sitl.yaml |
| Local SITL | `udp:127.0.0.1:14550` | If running sim_vehicle.py locally |
| Serial | `/dev/ttyACM0` | Real Pixhawk via USB |

Override with:
```bash
python3 -m autonomy.mission_manager \
  --vehicle-backend ardupilot_sitl \
  --connection "udp:127.0.0.1:14550"
```

## Troubleshooting

### SITL won't start
```bash
# Check Docker is running
docker ps

# Check for port conflicts
lsof -i :5760
lsof -i :14550

# View logs
docker compose -f infra/compose/docker-compose.sitl.yaml logs
```

### Connection refused
- Make sure SITL is fully booted (wait for "APM: EKF2 IMU1 is using GPS" in logs)
- Check the connection string matches your setup
- Try restarting SITL: `./ops/scripts/sitl.sh stop && ./ops/scripts/sitl.sh start`

### pymavlink not found
```bash
pip install pymavlink
```

## Next Steps

- **Split Device**: Try running mission manager on one machine, SITL on another
- **Companion Hybrid**: Connect to real Pixhawk (keeps simulation world)
- **Full Real**: Real drone, real world, real sensors

See `docs/roadmap-v1.md` for the full development roadmap.
