# Context: Sprint 2 — API + MQTT Layer

## What
Build the backend API layer: FastAPI server wrapping `vehicle_adapter` for commands, EMQX MQTT broker for high-performance multi-user telemetry streaming, and a WebSocket gateway for the browser. This is the communication backbone that connects the drone stack to the web UI.

## Why
- **Multi-user:** MQTT pub/sub means unlimited browser clients can subscribe to drone telemetry without any fan-out logic in the backend. EMQX handles millions of concurrent connections.
- **Command reliability:** QoS 1 on command topics means arm/takeoff/land delivery is confirmed even if the broker-to-subscriber path momentarily drops.
- **Decoupling:** vehicle_adapter publishes to MQTT; it does not know or care how many UIs are watching. The UI subscribes to MQTT; it does not know how vehicle_adapter works.
- **FastAPI for commands:** REST POST /command is simple, auditable, and works from any HTTP client. No WebSocket required for sending commands.

## Protocol Decision
**MQTT (EMQX) for telemetry + FastAPI REST for commands.**
- Telemetry: `drones/{vehicle_id}/telemetry` at 10Hz, QoS 0 (fire and forget — loss is OK, superseded immediately by next update)
- Commands: FastAPI POST → vehicle_adapter → MAVLink (synchronous, returns ACK)
- Status/progress: `drones/{vehicle_id}/mission/status`, QoS 1

NOT using: WebRTC (too complex for server-to-browser), gRPC-Web (overkill), raw WebSocket for telemetry (no multi-user pub/sub).

## Current State (after Sprint 1)
- ArduPilot SITL + Gazebo: running on EC2
- MAVROS2 + rosbridge: running on EC2, topics available
- vehicle_adapter: working MAVLink command execution
- API: nothing built yet
- MQTT broker: not installed
