#!/bin/bash
# Wrapper for ops/scripts/setup-dev-env.sh
# Usage: ./setup-dev-env.sh [--force]

cd "$(dirname "$0")"
exec ./ops/scripts/setup-dev-env.sh "$@"
