"""Mission manager that orchestrates missions with real or simulated vehicles."""

from __future__ import annotations

import argparse
from pathlib import Path
import sys
import time
from typing import Any

try:
    import yaml
except ImportError as exc:  # pragma: no cover - bootstrap environment guard
    print("missing dependency: pyyaml (pip install pyyaml)", file=sys.stderr)
    raise SystemExit(2) from exc

from adapters.vehicle_adapter import VehicleAdapter, VehicleCommand
from interfaces.config import get_config
from interfaces.logging import get_logger


log = get_logger("mission-manager")
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
    parser = argparse.ArgumentParser(description="Run mission manager")
    parser.add_argument(
        "--deployment",
        required=True,
        help="Path to deployment YAML, e.g. deployments/full_sitl__single_device.yaml",
    )
    parser.add_argument(
        "--vehicle-backend",
        default="ardupilot_sitl",
        choices=["stub", "ardupilot_sitl", "ardupilot_serial"],
        help="Backend for vehicle connection",
    )
    parser.add_argument(
        "--connection",
        help="MAVLink connection string (e.g., tcp:127.0.0.1:5760, udp:127.0.0.1:14550)",
    )
    parser.add_argument(
        "--start-sitl",
        action="store_true",
        help="Automatically start SITL if using ardupilot_sitl backend",
    )
    parser.add_argument(
        "--no-wait-ready",
        action="store_true",
        help="Skip waiting for vehicle GPS/health before first command",
    )
    parser.add_argument(
        "--wait-timeout",
        type=float,
        default=90.0,
        help="Timeout for vehicle ready wait (seconds, default: 90)",
    )
    parser.add_argument(
        "--force-arm",
        action="store_true",
        help="Use force arm (bypass pre-arm checks) - NOT for real flights",
    )
    parser.add_argument(
        "--verbose", "-v",
        action="store_true",
        help="Enable debug logging",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    deployment_path = ROOT_DIR / args.deployment
    
    # Load configuration
    config = get_config()
    
    sitl_manager = None
    
    # Use backend from args or config
    backend = args.vehicle_backend or config.vehicle.backend
    
    log.info("starting", deployment=args.deployment, backend=backend)

    # Auto-start SITL if requested
    if args.start_sitl and backend == "ardupilot_sitl":
        try:
            from simulation.sitl_manager import SITLManager
            # Use config values for SITL
            sitl_manager = SITLManager(
                mode=config.simulation.mode,
                version=config.simulation.sitl_version,
                vehicle_type=config.simulation.vehicle_type,
            )
            if not sitl_manager.start(wait=True, timeout=config.vehicle.timeouts.connection):
                log.error("failed to start SITL")
                return 1
            log.info("SITL started automatically")
        except Exception as e:
            log.error("failed to start SITL", error=str(e))
            return 1

    try:
        deployment = load_yaml(deployment_path)
        profile_ref = deployment["spec"]["profile"]
        profile = load_yaml(resolve_profile_path(profile_ref))

        mission_name = resolve_mission_name(deployment, profile)
        mission_path = ROOT_DIR / "missions" / f"{mission_name}.yaml"
        mission = load_yaml(mission_path)

        commands = scenario_to_commands(mission)
    except Exception as err:  # pragma: no cover - bootstrap CLI path
        log.error("failed to load configuration", error=str(err))
        if sitl_manager:
            sitl_manager.stop()
        return 1

    log.info("configuration loaded", 
             profile=profile_ref, 
             mission=mission_name, 
             commands=len(commands))

    topology_ref = deployment.get("spec", {}).get("topology")
    if topology_ref:
        log.info("topology", ref=topology_ref)

    # Create adapter with appropriate connection
    # Priority: CLI arg > deployment params > config > default
    connection_string = args.connection
    
    if not connection_string:
        deployment_params = deployment.get("spec", {}).get("params", {})
        connection_string = deployment_params.get("sitl_connection")
        if connection_string:
            log.info("using connection from deployment config", connection=connection_string)
    
    if not connection_string and sitl_manager:
        connection_string = sitl_manager.connection_string
    
    if not connection_string and backend == "ardupilot_sitl":
        connection_string = config.vehicle.connection_string
        log.info("using connection from config", connection=connection_string)
    
    adapter = VehicleAdapter(
        backend=backend,
        connection_string=connection_string,
        auto_connect=True,
        config=config,
    )
    log.info("adapter initialized", 
             backend=backend,
             connection=connection_string or "default")

    # Wait for vehicle ready before first command
    if not args.no_wait_ready and backend != "stub":
        # Check if connected first
        if not adapter.is_connected():
            log.error("not connected to vehicle - cannot proceed")
            adapter.disconnect()
            if sitl_manager:
                sitl_manager.stop()
            return 1
        
        log.info("waiting for vehicle ready (GPS, EKF)...")
        wait_timeout = args.wait_timeout or config.vehicle.timeouts.connection
        if not adapter.wait_for_ready(timeout=wait_timeout):
            log.error("vehicle not ready within timeout")
            adapter.disconnect()
            if sitl_manager:
                sitl_manager.stop()
            return 1

    # Apply force arm if requested (modify the arm command)
    # Use CLI arg, or config value
    force_arm = args.force_arm or config.vehicle.force_arm
    if force_arm:
        for cmd in commands:
            if cmd.name == "arm":
                cmd.payload["force"] = True
                log.warning("force arm enabled - bypassing safety checks")

    success = True
    for idx, command in enumerate(commands, 1):
        log.info("executing command", 
                 step=f"{idx}/{len(commands)}", 
                 command=command.name,
                 vehicle=command.payload.get("vehicle_id"))

        if args.verbose:
            log.debug("command payload", **command.payload)

        try:
            telemetry = adapter.execute(command)
        except Exception as err:
            log.error("command failed", 
                     command=command.name, 
                     error=str(err),
                     step=f"{idx}/{len(commands)}")
            success = False
            break

        # Log telemetry summary
        pos = telemetry["data"]["position"]
        state = telemetry["data"]["state"]
        battery = telemetry["data"]["battery"]
        
        log.info("telemetry received",
                vehicle=telemetry["vehicle_id"],
                armed=state["armed"],
                mode=state["mode"],
                alt_m=pos["alt_m"],
                battery_pct=battery["percent"],
                gps_ok=state["health_flags"].get("gps_ok", False))

    # Cleanup
    adapter.disconnect()
    if sitl_manager:
        log.info("stopping SITL")
        sitl_manager.stop()

    if success:
        log.info("mission completed successfully", 
                mission=mission_name,
                commands_executed=len(commands))
        return 0
    else:
        log.error("mission failed", 
                 mission=mission_name,
                 failed_at=f"{idx}/{len(commands)}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
