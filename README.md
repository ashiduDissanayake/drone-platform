# drone-platform

Modular, profile-driven, topology-aware drone platform monorepo.

V1 focus:
- Scope: Profile A (Full SITL), Profile C (Companion Hybrid)
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

## Quick start

1. Enter dev shell (if Nix installed):
   - `nix develop`
2. Run config validation:
   - `./ops/scripts/validate-config.sh`
3. Review onboarding docs:
   - `docs/onboarding/getting-started.md`

## Status

This bootstrap intentionally provides structure, contracts, and infra skeletons only.
Core autonomy/adapters implementation is deferred.
