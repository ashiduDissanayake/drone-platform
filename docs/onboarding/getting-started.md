# Getting Started

## Prerequisites
- Nix (optional but recommended)
- Bash
- Python 3.10+

## Setup
1. Clone repo.
2. Enter dev shell:
   - `nix develop`
3. Note the V1 default backend path:
   - Full SITL profile defaults to `ardupilot_sitl` for the vehicle component.
   - Gazebo remains the world simulator backend.
4. Run bootstrap helper:
   - `./ops/scripts/bootstrap-dev.sh`
5. Validate config model:
   - `python3 ops/scripts/validate-config.py --all`
6. Run mission manager stub:
   - `python3 -m autonomy.mission_manager --deployment deployments/full_sitl__single_device.yaml`

## Config workflow
1. Choose a profile in `profiles/`.
2. Choose a topology in `topologies/`.
3. Prepare inventory from `inventory/devices.example.yaml`.
4. Create or select deployment in `deployments/`.
5. Use `infra/ansible/` and `infra/compose/` as execution skeletons.
6. See `docs/onboarding/run-mission-stub.md` for CLI/Compose stub demos.
