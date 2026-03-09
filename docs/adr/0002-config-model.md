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

Deployment files are the composition boundary and must reference concrete profile/topology/inventory assets.
Validation tooling enforces that role assignments are consistent with topology roles and available inventory devices.

## Consequences
- Pros: pluggable composition, reduced coupling between mission logic and runtime placement, clear support for single-device and split-device variants.
- Cons: requires validation to prevent incompatible combinations and adds some configuration surface area.
