# Compose Skeleton

This directory holds role-oriented compose templates.

## Files
- `docker-compose.base.yaml`: base placeholder services for ArduPilot SITL, Gazebo, ROS2, QGC, and stub runtime channels.
- `docker-compose.full_sitl__single_device.yaml`: runnable override for mission-manager and vehicle-adapter stubs on one host.
- `compose.base.yml`: legacy placeholder from initial bootstrap (kept temporarily).

## Hybrid-ready transport placeholders
- `VEHICLE_ADAPTER_ENDPOINT` / `BIND_ENDPOINT` and `TRANSPORT_KIND` are included for future split-host transport.
- In Profile C, mission manager can remain on control/sim host while adapter binds on companion host.
