#!/bin/bash
# Wrapper for ops/scripts/quickstart.sh
# Usage: ./quickstart.sh

cd "$(dirname "$0")"
exec ./ops/scripts/quickstart.sh "$@"
