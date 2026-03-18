#!/bin/bash
# Wrapper for infra/scripts/cleanup-failed.sh
# Destroys AWS infrastructure to stop charges after failed deployment
# Usage: ./cleanup-failed.sh [--yes]

cd "$(dirname "$0")"
exec ./infra/scripts/cleanup-failed.sh "$@"
