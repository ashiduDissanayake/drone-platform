#!/bin/bash
# Wrapper for infra/scripts/get-connection.sh
# Shows connection details for cloud SITL
# Usage: ./get-connection.sh [--export]

cd "$(dirname "$0")"
exec ./infra/scripts/get-connection.sh "$@"
