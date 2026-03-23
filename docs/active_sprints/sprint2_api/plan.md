# Architecture Plan: Sprint 2 — API + MQTT Layer

## 1. Component Map

```
EC2
├── EMQX Broker (NEW)
│   ├── MQTT TCP: 1883 (internal)
│   ├── MQTT WebSocket: 8083 (browser clients connect here)
│   └── Dashboard: 18083 (admin UI)
│
├── api/ FastAPI server (NEW)
│   ├── POST /command           → vehicle_adapter → MAVLink
│   ├── POST /mission/run       → mission_manager
│   ├── GET  /mission/status    → current mission state
│   ├── GET  /health            → stack health check
│   └── Background task: MAVLink telemetry → EMQX publish loop
│
└── vehicle_adapter (existing, modified)
    └── Publishes telemetry to EMQX every 100ms (10Hz):
        Topic: drones/v1/telemetry
        Payload: { lat, lon, alt_m, armed, mode, battery_pct, vx, vy, vz }

Browser
└── MQTT.js connects to ws://15.207.113.11:8083/mqtt
    └── Subscribes to drones/v1/telemetry → live position updates
```

## 2. MQTT Topic Schema

| Topic | Direction | QoS | Payload |
|---|---|---|---|
| `drones/{id}/telemetry` | EC2 → Browser | 0 | JSON: position, state, battery |
| `drones/{id}/mission/status` | EC2 → Browser | 1 | JSON: step, command, progress |
| `drones/{id}/alerts` | EC2 → Browser | 1 | JSON: type, message, severity |

Commands go via FastAPI REST (not MQTT) to maintain synchronous error handling.

## 3. API Endpoints

```
POST /command
Body: { "vehicle_id": "v1", "command": "arm", "params": {} }
Returns: { "success": true, "telemetry": {...} }

POST /command
Body: { "vehicle_id": "v1", "command": "takeoff", "params": { "target_altitude_m": 10 } }

POST /command
Body: { "vehicle_id": "v1", "command": "goto_waypoint", "params": { "lat": -35.36, "lon": 149.16, "alt": 10 } }

POST /command
Body: { "vehicle_id": "v1", "command": "land", "params": {} }

POST /mission/run
Body: { "vehicle_id": "v1", "mission_yaml": "..." }
Returns: { "mission_id": "uuid", "status": "started" }

GET /mission/{mission_id}/status
Returns: { "step": 3, "total": 6, "current_command": "goto_waypoint", "complete": false }

GET /health
Returns: { "sitl": "connected", "gazebo": "running", "ros2": "active", "mqtt": "connected" }
```

## 4. Telemetry Publish Loop

```python
# In api/telemetry_publisher.py
async def telemetry_loop(adapter: VehicleAdapter, mqtt_client):
    while True:
        telem = adapter._connection.get_telemetry()
        payload = {
            "ts": time.time(),
            "lat": telem["position"]["lat"],
            "lon": telem["position"]["lon"],
            "alt_m": telem["position"]["alt_m"],
            "armed": telem["state"]["armed"],
            "mode": telem["state"]["mode"],
            "battery_pct": telem["battery"]["percent"],
        }
        mqtt_client.publish("drones/v1/telemetry", json.dumps(payload), qos=0)
        await asyncio.sleep(0.1)  # 10Hz
```

## 5. File Structure

```
api/
├── __init__.py
├── main.py              ← FastAPI app, lifespan, routes
├── routes/
│   ├── commands.py      ← POST /command
│   └── missions.py      ← POST /mission/run, GET /mission/{id}/status
├── services/
│   ├── telemetry.py     ← background MQTT publish loop
│   └── mission_runner.py ← async mission execution wrapper
└── config.py            ← API-specific config (MQTT host, etc.)
```

## 6. EMQX Setup

EMQX Community Edition via Docker on EC2:
```yaml
# infra/compose/emqx.yml
services:
  emqx:
    image: emqx/emqx:5.8
    ports:
      - "1883:1883"    # MQTT TCP
      - "8083:8083"    # MQTT over WebSocket
      - "18083:18083"  # Dashboard (restrict to VPN/your IP)
    environment:
      - EMQX_NAME=drone-platform
    volumes:
      - emqx-data:/opt/emqx/data
```

## 7. Security Group Changes

| Port | Protocol | Purpose |
|---|---|---|
| 8083 | TCP | MQTT WebSocket (browser) |
| 8000 | TCP | FastAPI (browser) |
| 18083 | TCP | EMQX dashboard (restrict to your IP) |
