# Compose Skeleton

This directory holds role-oriented compose templates.

## Files
- `docker-compose.base.yaml`: placeholder services for PX4, Gazebo, ROS2, and QGC.
- `compose.base.yml`: legacy placeholder from initial bootstrap (kept temporarily).

## Notes
- Each service includes `drone.role` and `drone.topology_role` labels.
- `RUN_HOST_ROLE` environment variables are placeholders for future topology-driven execution.
