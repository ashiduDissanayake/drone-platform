"""Vehicle adapter stub with contract-shaped telemetry for V1."""

from __future__ import annotations

import argparse
import json
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any


@dataclass
class VehicleCommand:
    name: str
    payload: dict[str, Any]


class VehicleAdapter:
    """Placeholder vehicle adapter that logs commands and emits fake telemetry."""

    def __init__(self, backend: str = "px4_sitl") -> None:
        self.backend = backend

    def execute(self, command: VehicleCommand) -> dict[str, Any]:
        print(f"[vehicle-adapter] {self.backend} would execute: {command.name} {command.payload}")
        return self._telemetry_for(command)

    def _telemetry_for(self, command: VehicleCommand) -> dict[str, Any]:
        vehicle_id = str(command.payload.get("vehicle_id", "vehicle-1"))
        position = {"lat": 37.4275, "lon": -122.1697, "alt_m": 0.0}
        velocity = {"vx_mps": 0.0, "vy_mps": 0.0, "vz_mps": 0.0}

        if command.name == "takeoff":
            position["alt_m"] = float(command.payload.get("target_altitude_m", 10.0))
            velocity["vz_mps"] = 1.0
        elif command.name == "goto_waypoint":
            position["lat"] = float(command.payload.get("lat", position["lat"]))
            position["lon"] = float(command.payload.get("lon", position["lon"]))
            position["alt_m"] = float(command.payload.get("alt", 10.0))
            velocity["vx_mps"] = 2.0
            velocity["vy_mps"] = 2.0
        elif command.name == "land":
            position["alt_m"] = 0.0
            velocity["vz_mps"] = -1.0

        return {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "vehicle_id": vehicle_id,
            "data": {
                "position": position,
                "velocity": velocity,
                "battery": {"voltage_v": 15.2, "percent": 92.0},
                "state": {
                    "armed": command.name not in {"disarm"},
                    "mode": "AUTO",
                    "health_flags": {"gps_ok": True, "link_ok": True},
                },
            },
        }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run vehicle adapter stub")
    parser.add_argument("--backend", default="px4_sitl")
    parser.add_argument("--command", default="arm", help="command name (arm/takeoff/goto_waypoint/land/disarm)")
    parser.add_argument(
        "--payload",
        default='{"vehicle_id": "vehicle-1"}',
        help="JSON payload for the command",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        payload = json.loads(args.payload)
    except json.JSONDecodeError as err:
        print(f"[vehicle-adapter][error] invalid payload JSON: {err}")
        return 1

    adapter = VehicleAdapter(backend=args.backend)
    telemetry = adapter.execute(VehicleCommand(name=args.command, payload=payload))
    print("[vehicle-adapter] telemetry:")
    print(json.dumps(telemetry, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
