#!/bin/bash
# Development environment bootstrap
# This is a wrapper - see setup-dev-env.sh for full implementation

set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo "=========================================="
echo "  Drone Platform - Dev Environment Setup"
echo "=========================================="
echo ""
echo "Running full setup script..."
echo ""

exec "${ROOT_DIR}/ops/scripts/setup-dev-env.sh" "$@"
