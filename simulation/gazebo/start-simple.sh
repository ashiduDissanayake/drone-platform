#!/bin/bash
cd "$(dirname "$0")"
docker compose -f docker-compose.simple.yaml down 2>/dev/null || true
docker compose -f docker-compose.simple.yaml up --build
