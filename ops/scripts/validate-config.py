#!/usr/bin/env python3
"""Validate deployment/profile/topology/inventory wiring for V1 config model."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path
from typing import Any

try:
    import yaml
except ImportError as exc:  # pragma: no cover - bootstrap environment guard
    print("[validate][error] missing dependency: pyyaml (pip install pyyaml)", file=sys.stderr)
    raise SystemExit(2) from exc


ROOT_DIR = Path(__file__).resolve().parents[2]


class ValidationError(Exception):
    pass


def load_yaml(path: Path) -> dict[str, Any]:
    if not path.exists():
        raise ValidationError(f"missing file: {path}")
    with path.open("r", encoding="utf-8") as handle:
        data = yaml.safe_load(handle)
    if not isinstance(data, dict):
        raise ValidationError(f"expected mapping at top-level: {path}")
    return data


def resolve_reference(value: str, base_dir: Path, suffix: str = ".yaml") -> Path:
    raw = Path(value)
    if raw.suffix:
        return ROOT_DIR / raw if not raw.is_absolute() else raw
    return base_dir / f"{value}{suffix}"


def validate_deployment(deployment_path: Path) -> None:
    deployment = load_yaml(deployment_path)
    spec = deployment.get("spec")
    if not isinstance(spec, dict):
        raise ValidationError(f"deployment missing spec mapping: {deployment_path}")

    profile_ref = spec.get("profile")
    topology_ref = spec.get("topology")
    inventory_ref = spec.get("inventory")
    assignments = spec.get("role_assignments")

    if not isinstance(profile_ref, str) or not profile_ref:
        raise ValidationError(f"deployment missing profile string: {deployment_path}")
    if not isinstance(topology_ref, str) or not topology_ref:
        raise ValidationError(f"deployment missing topology string: {deployment_path}")
    if not isinstance(inventory_ref, str) or not inventory_ref:
        raise ValidationError(f"deployment missing inventory string: {deployment_path}")
    if not isinstance(assignments, dict) or not assignments:
        raise ValidationError(f"deployment missing role_assignments map: {deployment_path}")

    profile_path = resolve_reference(profile_ref, ROOT_DIR / "profiles")
    topology_path = resolve_reference(topology_ref, ROOT_DIR / "topologies")
    inventory_path = resolve_reference(inventory_ref, ROOT_DIR / "inventory")

    profile = load_yaml(profile_path)
    topology = load_yaml(topology_path)
    inventory = load_yaml(inventory_path)

    if profile.get("kind") != "Profile":
        raise ValidationError(f"referenced profile is not kind=Profile: {profile_path}")
    if topology.get("kind") != "Topology":
        raise ValidationError(f"referenced topology is not kind=Topology: {topology_path}")
    if inventory.get("kind") != "Inventory":
        raise ValidationError(f"referenced inventory is not kind=Inventory: {inventory_path}")

    topology_spec = topology.get("spec")
    inventory_spec = inventory.get("spec")
    if not isinstance(topology_spec, dict):
        raise ValidationError(f"topology missing spec mapping: {topology_path}")
    if not isinstance(inventory_spec, dict):
        raise ValidationError(f"inventory missing spec mapping: {inventory_path}")

    topology_roles = topology_spec.get("device_roles")
    inventory_devices = inventory_spec.get("devices")
    if not isinstance(topology_roles, dict) or not topology_roles:
        raise ValidationError(f"topology missing device_roles map: {topology_path}")
    if not isinstance(inventory_devices, list) or not inventory_devices:
        raise ValidationError(f"inventory missing devices list: {inventory_path}")

    inventory_roles: set[str] = set()
    inventory_device_map: dict[str, str] = {}
    for device in inventory_devices:
        if not isinstance(device, dict):
            continue
        device_id = device.get("id")
        role = device.get("role")
        if isinstance(role, str):
            inventory_roles.add(role)
        if isinstance(device_id, str) and isinstance(role, str):
            inventory_device_map[device_id] = role

    for role, device_id in assignments.items():
        if role not in topology_roles:
            raise ValidationError(
                f"deployment role '{role}' not declared in topology device_roles ({topology_path})"
            )
        if role not in inventory_roles:
            raise ValidationError(
                f"deployment role '{role}' has no matching role in inventory devices ({inventory_path})"
            )
        if not isinstance(device_id, str) or not device_id:
            raise ValidationError(
                f"deployment role '{role}' must map to a non-empty device id ({deployment_path})"
            )
        actual_role = inventory_device_map.get(device_id)
        if actual_role is None:
            raise ValidationError(
                f"deployment role '{role}' references unknown device id '{device_id}' ({inventory_path})"
            )
        if actual_role != role:
            raise ValidationError(
                f"deployment role '{role}' mapped to '{device_id}' with inventory role '{actual_role}'"
            )


def list_deployments() -> list[Path]:
    return sorted((ROOT_DIR / "deployments").glob("*.yaml"))


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Validate drone-platform deployment configs")
    parser.add_argument(
        "--deployment",
        action="append",
        default=[],
        help="Deployment file path relative to repo root (can be provided multiple times)",
    )
    parser.add_argument(
        "--all",
        action="store_true",
        help="Validate all deployment YAML files in deployments/",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    candidates: list[Path] = []

    if args.all:
        candidates.extend(list_deployments())

    for rel in args.deployment:
        candidates.append(ROOT_DIR / rel)

    if not candidates:
        candidates = list_deployments()

    if not candidates:
        print("[validate][error] no deployment files found", file=sys.stderr)
        return 1

    exit_code = 0
    for deployment_path in candidates:
        try:
            validate_deployment(deployment_path)
            print(f"[validate][ok] {deployment_path.relative_to(ROOT_DIR)}")
        except ValidationError as err:
            print(f"[validate][error] {deployment_path.relative_to(ROOT_DIR)}: {err}", file=sys.stderr)
            exit_code = 1

    if exit_code == 0:
        print("[validate] OK")
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
