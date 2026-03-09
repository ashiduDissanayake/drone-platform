#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo "[bootstrap] root: ${ROOT_DIR}"

echo "[bootstrap] V1 bootstrap scaffold present."
echo "[bootstrap] next: run python3 ./ops/scripts/validate-config.py --all"
