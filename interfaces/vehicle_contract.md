# Vehicle Contract (V1)

Defines autonomy-facing vehicle control surface.

## Required commands
- `arm()`
- `disarm()`
- `takeoff(target_altitude_m)`
- `goto_waypoint(lat, lon, alt)`
- `land()`

## Required state
- `mode`
- `armed`
- `position`
- `velocity`
- `battery`

## Notes
- Interface must be transport-agnostic (no direct simulator assumptions).
- Adapter implementation decides MAVLink/PX4 specifics.
