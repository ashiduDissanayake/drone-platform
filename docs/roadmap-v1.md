# V1 Implementation Roadmap

This document outlines the phased approach to getting from stubs to a working drone platform.

## Current Status

✅ **Phase 0: Foundation** - DONE
- Repository structure
- Configuration model (Profile/Topology/Inventory/Deployment)
- **Structured logging with tags** - `[timestamp] [component] [LEVEL] message key=value`
- Basic validation
- Mission manager skeleton

## Phase 1: Real ArduPilot SITL Integration (Current Focus)

**Goal:** Replace stubs with actual ArduPilot SITL connection

### What This Means
Instead of the vehicle adapter returning fake telemetry, it will:
1. Launch/connect to ArduPilot SITL simulator
2. Send MAVLink commands for arm/takeoff/goto/land
3. Receive real telemetry from the simulator

### Tasks
- [ ] Add MAVLink dependency (`pymavlink`)
- [ ] Create `simulation/sitl_manager.py` - manages SITL lifecycle
- [ ] Update `adapters/vehicle_adapter/` to connect via MAVLink
- [ ] Test: Run mission manager → See actual drone fly in SITL

### Success Criteria
```bash
python3 -m autonomy.mission_manager --deployment deployments/full_sitl__single_device.yaml
# You should see actual MAVLink messages and the vehicle responding in the sim
```

---

## Phase 2: Split Device Deployment

**Goal:** Run mission manager on laptop, vehicle adapter on companion computer (or 2 VMs)

### Why This Order?
Split device is easier to debug **before** adding real hardware:
- Network issues are easier to solve than hardware issues
- You can see logs on both machines
- Validates the distributed architecture

### Tasks
- [ ] Add `inventory/devices.two-vm.yaml` example
- [ ] Create `deployments/full_sitl__split_device.yaml`
- [ ] Add network transport layer (MQTT/ZeroMQ/gRPC between components)
- [ ] Update Docker Compose for multi-device
- [ ] Add SSH-based deployment via Ansible

### Topology
```
[Laptop]                    [Raspberry Pi / VM]
mission-manager ──MQTT──▶   vehicle-adapter
                              │
                              ▼
                          ardupilot_sitl
```

### Success Criteria
```bash
# From laptop
python3 -m autonomy.mission_manager --deployment deployments/full_sitl__split_device.yaml
# Vehicle adapter runs on remote device, mission manager orchestrates from laptop
```

---

## Phase 3: Companion Hybrid (Real Vehicle + Simulated World)

**Goal:** Connect to real drone hardware but keep world simulated

### What This Means
- Real flight controller (Pixhawk) connected via USB/UART
- No GPS needed (simulated position)
- Safe testing - drone "thinks" it's flying but stays grounded

### Tasks
- [ ] Create `profiles/companion_hybrid.yaml`
- [ ] Update vehicle adapter for serial/USB connection
- [ ] Add `world_adapter` stub (simulates GPS/position)
- [ ] Safety checks (pre-arm validation, geofence)

### Success Criteria
Real Pixhawk responds to commands, but position is injected from simulation.

---

## Phase 4: Full Real Hardware

**Goal:** Real drone, real world, real sensors

### Tasks
- [ ] Perception pipeline integration
- [ ] Real GPS/compass validation
- [ ] Safety pilot override
- [ ] Outdoor testing procedures

---

## Decision: Split Device Before Real Software?

**YES - Here's why:**

| Approach | Risk | Debug Difficulty |
|----------|------|------------------|
| Real SITL → Split Device → Hybrid | Low → Med → High | Easy → Med → Hard |
| Real SITL → Hybrid → Split Device | Low → High → Med | Easy → Hard → Med |

**Split device teaches you:**
- Network partition handling
- Distributed log aggregation (why tags are crucial!)
- Service discovery
- Cross-machine Docker Compose

**Without split device experience**, debugging a real drone + companion computer is painful because you can't easily see what's happening on both sides.

---

## Logging System (Implemented)

The tagged logging you requested is now active:

```python
from interfaces.logging import get_logger

log = get_logger("mission-manager")
log.info("starting mission", vehicle="v1", mission="takeoff_land")
log.warning("battery low", percent=15.3)
log.error("connection timeout", retries=3)
```

Output:
```
[14:17:26.123] [mission-manager] [INFO] starting mission vehicle=v1 mission=takeoff_land
[14:17:26.456] [vehicle-adapter] [WARNING] battery low percent=15.30
[14:17:26.789] [telemetry-adapter] [ERROR] connection timeout retries=3
```

**Colors:**
- Cyan = Mission components
- Green = Vehicle components  
- Blue = World components
- Magenta = Telemetry
- Yellow = Infra/Warnings
- Red = Errors

---

## Recommended Next Steps

1. **Review this roadmap** - Does the order make sense for your setup?
2. **Phase 1: Real SITL** - Shall I implement the MAVLink integration?
3. **Setup test environment** - Do you have ArduPilot SITL installed, or should I add it to the Nix flake?

To proceed with Phase 1, I need to know:
- Do you want to use the existing ArduPilot SITL (requires manual install) or Docker-based SITL?
- Should the vehicle adapter spawn SITL, or connect to an already-running instance?
