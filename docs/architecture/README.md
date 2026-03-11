# Architecture Docs

- `overview.md`: model summary and V1 scope context.
- `v1-scope.md`: in-scope vs out-of-scope boundaries.
- `infra.md`: how infrastructure skeleton maps to profile/topology/deployment.
- `mission-manager.md`: mission orchestration responsibility and adapter boundary.

## V1 usage patterns

### Profile A + T1 (single device)
- `profile`: `full_sitl`
- default vehicle backend tag: `ardupilot_sitl`
- `topology`: `single_device`
- Deployment maps all role bindings to one device role (`control_host`).
- Compose services can run on one host while still preserving role labels.

### Profile A + T2 (split device)
- `profile`: `full_sitl`
- `topology`: `split_device`
- Deployment assigns role groups across `companion_host`, `sim_host`, and `gcs_host`.
- Ansible inventory groups and compose role labels preserve distributed placement.
