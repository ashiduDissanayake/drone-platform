# Mission Contract (V1)

Defines mission manager interaction model.

## Mission shape
- `mission_id`
- `steps`: ordered list of mission primitives
- `constraints`: timeout, geofence, safety policy

## V1 scenario
- `takeoff -> waypoint -> land`

## Adapter boundary
Mission manager depends only on contracts, not simulator or hardware internals.
