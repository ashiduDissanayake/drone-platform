#!/bin/bash
# Wrapper for infra/scripts/update-sg-ip.sh
# Updates AWS Security Group to allow your current IP
# Usage: ./update-sg-ip.sh

cd "$(dirname "$0")"
exec ./infra/scripts/update-sg-ip.sh "$@"
