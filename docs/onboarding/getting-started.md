# Getting Started

## Prerequisites
- Nix (optional but recommended)
- Bash
- Python 3.10+

## Setup
1. Clone repo.
2. Enter dev shell:
   - `nix develop`
3. Run bootstrap helper:
   - `./ops/scripts/bootstrap-dev.sh`
4. Validate config model:
   - `python3 ops/scripts/validate-config.py --all`

## Config workflow
1. Choose a profile in `profiles/`.
2. Choose a topology in `topologies/`.
3. Prepare inventory from `inventory/devices.example.yaml`.
4. Create or select deployment in `deployments/`.
5. Use `infra/ansible/` and `infra/compose/` as execution skeletons.
