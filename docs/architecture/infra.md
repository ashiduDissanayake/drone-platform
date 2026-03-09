# Infrastructure Skeleton (V1)

## Purpose
Provide a reproducible, role-oriented deployment path without locking into deep implementation details.

## Components
- `infra/ansible/`: host orchestration and provisioning skeleton.
- `infra/compose/docker-compose.base.yaml`: base service skeleton for PX4/Gazebo/ROS2/QGC.

## How it maps to the config model
1. Deployment selects a `profile`, `topology`, and `inventory`.
2. Topology defines runtime role placement (`sim_host`, `companion_host`, `gcs_host`, etc.).
3. Inventory provides concrete devices for those roles.
4. Ansible inventory groups and compose role labels are the execution bridge.

## Practical flow
1. Validate deployment config (`python3 ops/scripts/validate-config.py --all`).
2. Populate `infra/ansible/inventory.yml` with device hosts from inventory.
3. Apply playbooks in `infra/ansible/site.yml`.
4. Run compose stack per role/host strategy.

This is a skeleton only; role tasks and compose overrides are intentionally minimal in V1 bootstrap.
