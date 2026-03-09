# ADR 0001: Use a Monorepo

- Status: Accepted
- Date: 2026-03-09

## Context
The platform must evolve quickly while preserving coherent interfaces across autonomy, adapters, config models, and infra automation.

## Decision
Use a single monorepo for V1.

## Consequences
- Pros: simpler change coordination; shared contracts and docs; single CI surface.
- Cons: requires discipline in ownership boundaries.
