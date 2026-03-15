# drone-platform

ArduPilot-first, modular, profile-driven, topology-aware drone platform monorepo.

V1 focus:
- Scope: Profile A (Full SITL), Profile C (Companion Hybrid)
- Autopilot default: ArduPilot SITL (kept behind the vehicle adapter boundary)
- Topologies: T1 (Single Device), T2 (Split Device)
- Scenario: takeoff -> waypoint -> land
- Constraint: multi-device deployment from day one (no localhost-only assumptions)

## Repository layout

- `docs/` Architecture docs, ADRs, onboarding guides.
- `profiles/` Defines what is simulated vs real.
- `topologies/` Defines where services run by role.
- `inventory/` Defines available physical devices.
- `deployments/` Binds profile + topology + inventory for a runnable selection.
- `interfaces/` Stable contracts between autonomy and adapters.
- `autonomy/` Mission/business logic (stubbed in V1 bootstrap).
- `adapters/` Vehicle/world/telemetry integrations (stubbed in V1 bootstrap).
- `simulation/` Simulation integration placeholders.
- `infra/ansible/` Provisioning and deployment automation skeleton.
- `infra/compose/` Container composition skeleton.
- `ops/scripts/` Developer bootstrap and config validation scripts.
- `.github/workflows/` CI scaffolding.

## V1 model

- `profile`: what is simulated vs real.
- `topology`: where roles run.
- `inventory`: what devices exist.
- `deployment`: chosen profile + topology + inventory combination.

## Development shell (macOS and Linux)

1. Install Nix with flakes enabled.
2. Enter the shell from repo root:
   - `nix develop`
3. Verify config model wiring:
   - `python3 ops/scripts/validate-config.py --all`

The shell includes Python, YAML linting, pre-commit, and CLI tools for Docker Compose and Ansible.

## Quick start

1. Optional bootstrap helper:
   - `./ops/scripts/bootstrap-dev.sh`
2. Run config validation:
   - `python3 ops/scripts/validate-config.py --all`
3. Run mission stub:
   - `python3 -m autonomy.mission_manager --deployment deployments/full_sitl__single_device.yaml`
4. Review onboarding docs:
   - `docs/onboarding/getting-started.md`

## Status

This bootstrap intentionally provides structure, contracts, and infra skeletons only.
Core autonomy/adapters implementation is deferred.
