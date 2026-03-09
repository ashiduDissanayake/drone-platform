# ADR 0004: Nix + Ansible + Docker Compose for V1 Reproducibility

- Status: Accepted
- Date: 2026-03-09

## Context
V1 needs reproducible developer environment and deploy automation without overbuilding packaging.

## Decision
- Nix for dev tooling shell.
- Ansible for host orchestration/provisioning.
- Docker Compose for service composition skeleton.

## Consequences
- Pros: reproducible local tooling and clear infra path.
- Cons: operators must learn three tools.
