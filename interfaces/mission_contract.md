# Mission Contract (V1)

Defines mission scenario format consumed by mission manager.

## Mission message format

```yaml
mission_id: string
vehicle_id: string
actions:
  - action: takeoff
    params:
      target_altitude_m: 10
  - action: waypoint
    params:
      lat: 37.0
      lon: -122.0
      alt: 12
  - action: land
    params: {}
constraints:
  timeout_s: 300
```

## Rules
- `actions` is an ordered list of high-level steps.
- Each action is adapter-agnostic and maps to the vehicle contract.
- V1 required scenario is `takeoff -> waypoint -> land`.
