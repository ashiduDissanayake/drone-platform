"""Mission manager skeleton that resolves deployment -> profile -> mission catalog."""

from __future__ import annotations

import argparse
from pathlib import Path
import sys
from typing import Any

try:
    import yaml
except ImportError as exc:  # pragma: no cover - bootstrap environment guard
    print("missing dependency: pyyaml (pip install pyyaml)", file=sys.stderr)
    raise SystemExit(2) from exc

from adapters.vehicle_adapter import VehicleAdapter, VehicleCommand


ROOT_DIR = Path(__file__).resolve().parents[2]


def load_yaml(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        data = yaml.safe_load(handle)
    if not isinstance(data, dict):
        raise ValueError(f"expected mapping in {path}")
    return data


def resolve_profile_path(profile_ref: str) -> Path:
    ref_path = Path(profile_ref)
    if ref_path.suffix:
        return ROOT_DIR / ref_path
    return ROOT_DIR / "profiles" / f"{profile_ref}.yaml"


def resolve_mission_name(deployment: dict[str, Any], profile: dict[str, Any]) -> str:
    dep_mission = (
        deployment.get("spec", {})
        .get("params", {})
        .get("mission")
    )
    if isinstance(dep_mission, str) and dep_mission:
        return dep_mission

    profile_mission = (
        profile.get("spec", {})
        .get("mission_scenario", {})
        .get("name")
    )
    if isinstance(profile_mission, str) and profile_mission:
        return profile_mission

    raise ValueError("mission scenario name not found in deployment params or profile")


def scenario_to_commands(mission: dict[str, Any]) -> list[VehicleCommand]:
    actions = mission.get("spec", {}).get("actions")
    vehicle_id = mission.get("spec", {}).get("vehicle_id", "vehicle-1")
    if not isinstance(actions, list) or not actions:
        raise ValueError("mission spec.actions must be a non-empty list")

    commands: list[VehicleCommand] = []
    for item in actions:
        if not isinstance(item, dict):
            raise ValueError("mission action entries must be mappings")
        action = item.get("action")
        params = item.get("params", {})
        if not isinstance(action, str) or not action:
            raise ValueError("mission action is missing a non-empty 'action' field")
        if not isinstance(params, dict):
            raise ValueError(f"mission action '{action}' params must be a mapping")

        payload: dict[str, Any] = {"vehicle_id": vehicle_id}
        payload.update(params)
        commands.append(VehicleCommand(name=action, payload=payload))
    return commands


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run mission manager stub")
    parser.add_argument(
        "--deployment",
        required=True,
        help="Path to deployment YAML, e.g. deployments/full_sitl__single_device.yaml",
    )
    parser.add_argument(
        "--vehicle-backend",
        default="ardupilot_sitl",
        help="Backend tag used by the vehicle adapter stub",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    deployment_path = ROOT_DIR / args.deployment

    try:
        deployment = load_yaml(deployment_path)
        profile_ref = deployment["spec"]["profile"]
        profile = load_yaml(resolve_profile_path(profile_ref))

        mission_name = resolve_mission_name(deployment, profile)
        mission_path = ROOT_DIR / "missions" / f"{mission_name}.yaml"
        mission = load_yaml(mission_path)

        commands = scenario_to_commands(mission)
    except Exception as err:  # pragma: no cover - bootstrap CLI path
        print(f"[mission-manager][error] {err}", file=sys.stderr)
        return 1

    print(f"[mission-manager] deployment: {args.deployment}")
    print(f"[mission-manager] mission: {mission_name}")

    adapter = VehicleAdapter(backend=args.vehicle_backend)
    for command in commands:
        if command.name == "arm":
            print(f"[mission-manager] arming {command.payload['vehicle_id']}")
        elif command.name == "takeoff":
            alt = command.payload.get("target_altitude_m", "?")
            print(f"[mission-manager] takeoff to {alt}m")
        elif command.name == "goto_waypoint":
            lat = command.payload.get("lat", "?")
            lon = command.payload.get("lon", "?")
            alt = command.payload.get("alt", "?")
            print(f"[mission-manager] go to waypoint lat={lat} lon={lon} alt={alt}")
        elif command.name == "land":
            print("[mission-manager] land")
        elif command.name == "disarm":
            print(f"[mission-manager] disarming {command.payload['vehicle_id']}")
        else:
            print(f"[mission-manager] execute {command.name}")

        telemetry = adapter.execute(command)
        print(
            "[mission-manager] telemetry state: "
            f"armed={telemetry['data']['state']['armed']} "
            f"alt={telemetry['data']['position']['alt_m']}"
        )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
