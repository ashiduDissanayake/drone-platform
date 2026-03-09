# ADR 0003: Multi-Device Deployability from Day One

- Status: Accepted
- Date: 2026-03-09

## Context
Platform targets realistic deployments where roles run across multiple devices.

## Decision
Treat multi-device support as a mandatory baseline. Avoid localhost-only assumptions in topology/contracts.

## Consequences
- Pros: architecture matches target reality early.
- Cons: slightly higher initial setup complexity.
