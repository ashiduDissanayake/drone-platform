# Vehicle Contract (V1)

Defines the transport-agnostic interface between mission manager and vehicle adapter.

## Command inputs (mission manager -> vehicle adapter)
- `arm`
  - payload: `{ "vehicle_id": "string" }`
- `disarm`
  - payload: `{ "vehicle_id": "string" }`
- `takeoff`
  - payload: `{ "vehicle_id": "string", "target_altitude_m": "number" }`
- `goto_waypoint`
  - payload: `{ "vehicle_id": "string", "lat": "number", "lon": "number", "alt": "number" }`
- `land`
  - payload: `{ "vehicle_id": "string" }`

## Telemetry outputs (vehicle adapter -> mission manager)
- `position`: `{ "lat": "number", "lon": "number", "alt_m": "number" }`
- `velocity`: `{ "vx_mps": "number", "vy_mps": "number", "vz_mps": "number" }`
- `battery`: `{ "voltage_v": "number", "percent": "number" }`
- `state`: `{ "armed": "boolean", "mode": "string", "health_flags": "object" }`
- envelope: `{ "timestamp": "string", "vehicle_id": "string", "data": "object" }`

## Contract constraints
- Must not hardcode simulator-specific assumptions.
- Must support distributed deployments where producer/consumer are on different devices.
