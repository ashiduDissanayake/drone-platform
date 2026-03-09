#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

required_files=(
  "profiles/full_sitl.yaml"
  "profiles/companion_hybrid.yaml"
  "topologies/single_device.yaml"
  "topologies/split_device.yaml"
  "inventory/devices.example.yaml"
  "deployments/full_sitl__single_device.yaml"
  "deployments/full_sitl__split_device.yaml"
)

echo "[validate] checking required files"
for f in "${required_files[@]}"; do
  if [[ ! -f "${ROOT_DIR}/${f}" ]]; then
    echo "[validate][error] missing ${f}"
    exit 1
  fi
done

echo "[validate] checking minimal schema keys"
check_key() {
  local file="$1"
  local key="$2"
  if ! grep -Eq "^[[:space:]]*${key}:[[:space:]]*" "${ROOT_DIR}/${file}"; then
    echo "[validate][error] ${file} missing key: ${key}"
    exit 1
  fi
}

check_key "profiles/full_sitl.yaml" "kind"
check_key "profiles/full_sitl.yaml" "spec"
check_key "profiles/companion_hybrid.yaml" "kind"
check_key "topologies/single_device.yaml" "role_bindings"
check_key "topologies/split_device.yaml" "role_bindings"
check_key "inventory/devices.example.yaml" "devices"
check_key "deployments/full_sitl__single_device.yaml" "profile"
check_key "deployments/full_sitl__single_device.yaml" "topology"
check_key "deployments/full_sitl__split_device.yaml" "profile"
check_key "deployments/full_sitl__split_device.yaml" "topology"

echo "[validate] checking deployment references"
if ! grep -Eq "^[[:space:]]*profile:[[:space:]]*full_sitl" "${ROOT_DIR}/deployments/full_sitl__single_device.yaml"; then
  echo "[validate][error] full_sitl__single_device profile mismatch"
  exit 1
fi

if ! grep -Eq "^[[:space:]]*topology:[[:space:]]*single_device" "${ROOT_DIR}/deployments/full_sitl__single_device.yaml"; then
  echo "[validate][error] full_sitl__single_device topology mismatch"
  exit 1
fi

if ! grep -Eq "^[[:space:]]*topology:[[:space:]]*split_device" "${ROOT_DIR}/deployments/full_sitl__split_device.yaml"; then
  echo "[validate][error] full_sitl__split_device topology mismatch"
  exit 1
fi

if ! grep -Eq "^[[:space:]]*profile:[[:space:]]*full_sitl" "${ROOT_DIR}/deployments/full_sitl__split_device.yaml"; then
  echo "[validate][error] full_sitl__split_device profile mismatch"
  exit 1
fi

echo "[validate] OK"
