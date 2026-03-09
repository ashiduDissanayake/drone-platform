# Run Mission Stub

## Local CLI demo
From repo root:

1. Validate configs:
   - `python3 ops/scripts/validate-config.py --all`
2. Run mission manager against single-device deployment:
   - `python3 -m autonomy.mission_manager --deployment deployments/full_sitl__single_device.yaml`

Expected output:
- Ordered mission commands (`arm`, `takeoff`, `goto_waypoint`, `land`, `disarm`).
- Vehicle adapter placeholder execution logs.
- Telemetry state summaries after each command.

## Compose demo
From `infra/compose/`:

1. `docker compose -f docker-compose.base.yaml -f docker-compose.full_sitl__single_device.yaml run --rm mission_manager`

This runs mission-manager and vehicle-adapter stubs as separate services in the compose model.
