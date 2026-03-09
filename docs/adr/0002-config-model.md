# ADR 0002: Profile/Topology/Inventory/Deployment Model

- Status: Accepted
- Date: 2026-03-09

## Context
V1 needs reproducible deployments across mixed simulation and real hardware without coupling logic to hostnames.

## Decision
Model system configuration with four layers:
- Profile: simulated vs real components.
- Topology: role-to-device placement.
- Inventory: concrete device capabilities.
- Deployment: selected composition.

## Consequences
- Pros: pluggable and explicit deployment composition.
- Cons: requires validation to prevent incompatible combinations.
