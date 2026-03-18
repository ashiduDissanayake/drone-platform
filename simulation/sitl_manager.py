"""SITL (Software-in-the-Loop) lifecycle manager.

Handles starting, monitoring, and connecting to ArduPilot SITL.
Works with dronekit-sitl, Docker, or local SITL installation.
"""

from __future__ import annotations

import subprocess
import sys
import time
from pathlib import Path
from typing import Any

from interfaces.config import get_config
from interfaces.logging import get_logger


log = get_logger("sitl-manager")

# Legacy defaults (used when config is not available)
_DRONEKIT_CONNECTION = "tcp:127.0.0.1:5760"
_DOCKER_CONNECTION = "tcp:127.0.0.1:5760"
_LOCAL_CONNECTION = "udp:127.0.0.1:14550"
_EXTERNAL_CONNECTION = "tcp:127.0.0.1:5760"


class SITLManager:
    """Manages ArduPilot SITL lifecycle.
    
    Modes:
    - local: Use locally installed SITL
    - docker: Use Docker Compose SITL (newest, builds from source)
    - external: Connect to already-running SITL
    
    Usage:
        manager = SITLManager(mode="docker")
        if manager.start():
            # SITL is ready, connection available at manager.connection_string
            manager.stop()
    """
    
    def __init__(
        self,
        mode: str | None = None,
        connection_string: str | None = None,
        vehicle_type: str | None = None,
        version: str | None = None,
        docker_compose_file: str | None = None,
        config=None,
    ) -> None:
        """Initialize SITL manager.
        
        Args:
            mode: "local", "docker", or "external". Uses config if None.
            connection_string: Override the default connection string
            vehicle_type: "copter", "plane", "rover", etc. Uses config if None.
            version: SITL version. Uses config if None.
            docker_compose_file: Path to docker-compose.sitl.yaml
            config: Configuration object. Loads from file if None.
        """
        # Load config if not provided
        self._config = config or get_config()
        
        # Use config values as defaults
        self.mode = mode or self._config.simulation.mode
        self.vehicle_type = vehicle_type or self._config.simulation.vehicle_type
        self.version = version or self._config.simulation.sitl_version
        self._process: subprocess.Popen | None = None
        
        # Set connection string
        if connection_string:
            self.connection_string = connection_string
        elif self.mode == "docker":
            self.connection_string = _DOCKER_CONNECTION
        elif self.mode == "local":
            self.connection_string = _LOCAL_CONNECTION
        else:
            self.connection_string = _EXTERNAL_CONNECTION
        
        # Docker compose file path
        if docker_compose_file:
            self._compose_file = Path(docker_compose_file)
        else:
            repo_root = Path(__file__).resolve().parents[1]
            self._compose_file = (
                repo_root / "infra" / "compose" / "docker-compose.sitl.yaml"
            )
        
        log.info("sitl manager initialized",
                mode=self.mode,
                vehicle=self.vehicle_type,
                version=self.version,
                connection=self.connection_string)
    
    def start(self, wait: bool = True, timeout: float | None = None) -> bool:
        """Start SITL.
        
        Args:
            wait: Wait for SITL to be ready
            timeout: Maximum time to wait in seconds. Uses config if None.
            
        Returns:
            True if SITL started successfully
        """
        actual_timeout = timeout or self._config.vehicle.timeouts.connection
        
        if self.mode == "docker":
            return self._start_docker(wait, actual_timeout)
        elif self.mode == "local":
            return self._start_local(wait, actual_timeout)
        elif self.mode == "external":
            log.info("external mode - assuming SITL already running")
            return self._wait_for_connection(actual_timeout) if wait else True
        else:
            log.error("unknown mode", mode=self.mode)
            return False
    
    def _start_docker(self, wait: bool, timeout: float) -> bool:
        """Start Docker-based SITL."""
        log.info("starting docker sitl", compose_file=str(self._compose_file))
        
        if not self._compose_file.exists():
            log.error("docker compose file not found", path=str(self._compose_file))
            return False
        
        try:
            # Check if already running
            result = subprocess.run(
                ["docker", "compose", "-f", str(self._compose_file), "ps", "-q"],
                capture_output=True,
                text=True,
                check=False,
            )
            if result.stdout.strip():
                log.info("docker sitl already running")
                return self._wait_for_connection(timeout) if wait else True
            
            # Start SITL (build if needed)
            log.info("building/starting docker sitl (this may take a while)...")
            subprocess.run(
                ["docker", "compose", "-f", str(self._compose_file), "up", "-d", "--build"],
                check=True,
                capture_output=True,
            )
            log.info("docker sitl started")
            
            if wait:
                return self._wait_for_connection(timeout)
            return True
            
        except subprocess.CalledProcessError as e:
            log.error("failed to start docker sitl", error=str(e))
            return False
        except FileNotFoundError:
            log.error("docker not found - is docker installed?")
            return False
    
    def _start_local(self, wait: bool, timeout: float) -> bool:
        """Start local SITL installation."""
        log.info("starting local sitl", vehicle=self.vehicle_type)
        
        # Check for sim_vehicle.py
        ardupilot_path = Path.home() / "ardupilot"
        sim_vehicle = ardupilot_path / "Tools" / "autotest" / "sim_vehicle.py"
        
        if not sim_vehicle.exists():
            log.error("sim_vehicle.py not found", expected_path=str(sim_vehicle))
            log.info("hint: install ardupilot or use mode='dronekit'")
            return False
        
        try:
            self._process = subprocess.Popen(
                [
                    sys.executable,
                    str(sim_vehicle),
                    "-v", self.vehicle_type,
                    "-L", "Home",
                    "--out", "udp:127.0.0.1:14550",
                    "--no-rebuild",
                ],
                cwd=str(ardupilot_path),
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
            log.info("local sitl started", pid=self._process.pid)
            
            if wait:
                return self._wait_for_connection(timeout)
            return True
            
        except Exception as e:
            log.error("failed to start local sitl", error=str(e))
            return False
    
    def _wait_for_connection(self, timeout: float) -> bool:
        """Wait for MAVLink connection to be available."""
        log.info("waiting for sitl connection", timeout=timeout)
        
        try:
            from pymavlink import mavutil
        except ImportError:
            log.error("pymavlink not installed")
            return False
        
        start = time.time()
        while time.time() - start < timeout:
            try:
                master = mavutil.mavlink_connection(self.connection_string)
                master.wait_heartbeat(timeout=2.0)
                master.close()
                log.info("sitl connection ready",
                        elapsed=f"{time.time() - start:.1f}s")
                return True
            except Exception:
                time.sleep(1.0)
        
        log.error("timeout waiting for sitl connection")
        return False
    
    def stop(self) -> bool:
        """Stop SITL.
        
        Returns:
            True if stopped successfully
        """
        if self.mode == "docker":
            return self._stop_docker()
        elif self.mode == "local" and self._process:
            return self._stop_local()
        return True
    
    def _stop_docker(self) -> bool:
        """Stop Docker-based SITL."""
        log.info("stopping docker sitl")
        try:
            subprocess.run(
                ["docker", "compose", "-f", str(self._compose_file), "down"],
                check=True,
                capture_output=True,
            )
            log.info("docker sitl stopped")
            return True
        except subprocess.CalledProcessError as e:
            log.error("failed to stop docker sitl", error=str(e))
            return False
    
    def _stop_local(self) -> bool:
        """Stop local SITL."""
        if self._process:
            log.info("stopping local sitl", pid=self._process.pid)
            self._process.terminate()
            try:
                self._process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self._process.kill()
            log.info("local sitl stopped")
        return True
    
    def is_running(self) -> bool:
        """Check if SITL is running."""
        if self.mode == "docker":
            try:
                result = subprocess.run(
                    ["docker", "compose", "-f", str(self._compose_file), "ps", "-q"],
                    capture_output=True,
                    text=True,
                    check=False,
                )
                return bool(result.stdout.strip())
            except Exception:
                return False
        elif self.mode == "local" and self._process:
            return self._process.poll() is None
        return False


def main() -> int:
    """CLI for SITL management."""
    import argparse
    
    parser = argparse.ArgumentParser(description="Manage ArduPilot SITL")
    parser.add_argument("command", choices=["start", "stop", "status"])
    parser.add_argument("--mode", default="docker", 
                       choices=["docker", "local", "external"])
    parser.add_argument("--connection", help="MAVLink connection string")
    parser.add_argument("--vehicle", default="copter", help="Vehicle type")
    parser.add_argument("--version", default="4.0", help="SITL version (e.g., 3.3, 4.0, 4.3)")
    parser.add_argument("--wait", action="store_true", default=True, help="Wait for ready (default: True)")
    parser.add_argument("--no-wait", action="store_false", dest="wait", help="Don't wait for ready")
    parser.add_argument("--timeout", type=float, default=60.0, help="Timeout in seconds")
    
    args = parser.parse_args()
    
    manager = SITLManager(
        mode=args.mode,
        connection_string=args.connection,
        vehicle_type=args.vehicle,
        version=args.version,
    )
    
    if args.command == "start":
        if manager.start(wait=args.wait, timeout=args.timeout):
            print(f"\nSITL ready at: {manager.connection_string}")
            return 0
        return 1
    
    elif args.command == "stop":
        return 0 if manager.stop() else 1
    
    elif args.command == "status":
        if manager.is_running():
            print(f"SITL is running ({manager.mode})")
            print(f"Connection: {manager.connection_string}")
            return 0
        else:
            print("SITL is not running")
            return 1
    
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
