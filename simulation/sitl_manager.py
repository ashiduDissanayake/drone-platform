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

from interfaces.logging import get_logger


log = get_logger("sitl-manager")


class SITLManager:
    """Manages ArduPilot SITL lifecycle.
    
    Modes:
    - dronekit: Use dronekit-sitl Python package (Copter 3.3 - old but easy)
    - dronekit-4: Use dronekit-sitl with Copter 4.0 (better EKF)
    - docker: Use Docker Compose SITL (newest, builds from source)
    - local: Use locally installed SITL
    - external: Connect to already-running SITL
    
    Usage:
        manager = SITLManager(mode="dronekit-4")
        if manager.start():
            # SITL is ready, connection available at manager.connection_string
            manager.stop()
    """
    
    # Connection strings for different modes
    DRONEKIT_CONNECTION = "tcp:127.0.0.1:5760"  # Default dronekit-sitl
    DOCKER_CONNECTION = "tcp:127.0.0.1:5760"    # TCP from Docker container
    LOCAL_CONNECTION = "udp:127.0.0.1:14550"     # UDP from local SITL
    EXTERNAL_CONNECTION = "tcp:127.0.0.1:5760"   # Default external
    
    def __init__(
        self,
        mode: str = "dronekit-4",
        connection_string: str | None = None,
        vehicle_type: str = "copter",
        version: str = "4.0",
        docker_compose_file: str | None = None,
    ) -> None:
        """Initialize SITL manager.
        
        Args:
            mode: "dronekit", "dronekit-4", "docker", "local", or "external"
            connection_string: Override the default connection string
            vehicle_type: "copter", "plane", "rover", etc.
            version: SITL version (e.g., "3.3", "4.0", "4.3")
            docker_compose_file: Path to docker-compose.sitl.yaml
        """
        self.mode = mode
        self.vehicle_type = vehicle_type
        self.version = version
        self._process: subprocess.Popen | None = None
        self._sitl_instance: Any = None  # For dronekit-sitl
        
        # Set connection string
        if connection_string:
            conn_str = connection_string
        elif mode in ("dronekit", "dronekit-4"):
            conn_str = self.DRONEKIT_CONNECTION
        elif mode == "docker":
            conn_str = self.DOCKER_CONNECTION
        elif mode == "local":
            conn_str = self.LOCAL_CONNECTION
        else:
            conn_str = self.EXTERNAL_CONNECTION
        
        self.connection_string = conn_str
        
        # Docker compose file path
        if docker_compose_file:
            self._compose_file = Path(docker_compose_file)
        else:
            repo_root = Path(__file__).resolve().parents[1]
            self._compose_file = (
                repo_root / "infra" / "compose" / "docker-compose.sitl.yaml"
            )
        
        log.info("sitl manager initialized",
                mode=mode,
                vehicle=vehicle_type,
                version=version,
                connection=conn_str)
    
    def start(self, wait: bool = True, timeout: float = 60.0) -> bool:
        """Start SITL.
        
        Args:
            wait: Wait for SITL to be ready
            timeout: Maximum time to wait in seconds
            
        Returns:
            True if SITL started successfully
        """
        if self.mode in ("dronekit", "dronekit-4"):
            return self._start_dronekit(wait, timeout)
        elif self.mode == "docker":
            return self._start_docker(wait, timeout)
        elif self.mode == "local":
            return self._start_local(wait, timeout)
        elif self.mode == "external":
            log.info("external mode - assuming SITL already running")
            return self._wait_for_connection(timeout) if wait else True
        else:
            log.error("unknown mode", mode=self.mode)
            return False
    
    def _start_dronekit(self, wait: bool, timeout: float) -> bool:
        """Start SITL using dronekit-sitl."""
        log.info("starting dronekit-sitl", 
                vehicle=self.vehicle_type, 
                version=self.version)
        
        try:
            from dronekit_sitl import SITL
        except ImportError:
            log.error("dronekit-sitl not installed. Run: pip install dronekit-sitl")
            return False
        
        try:
            # Start SITL
            self._sitl_instance = SITL()
            
            # Download and start the vehicle
            log.info("downloading SITL binary...", version=self.version)
            self._sitl_instance.download(self.vehicle_type, self.version, verbose=True)
            
            # Launch without await_ready (we'll wait ourselves)
            log.info("launching SITL...")
            self._sitl_instance.launch(
                ["--model", "quad", "--home", "-35.363261,149.165230,584,353"],
                verbose=True,
                await_ready=False,
                restart=True,
            )
            
            # Get connection string
            self.connection_string = self._sitl_instance.connection_string()
            
            log.info("dronekit-sitl started", connection=self.connection_string)
            
            if wait:
                return self._wait_for_connection(timeout)
            return True
            
        except Exception as e:
            log.error("failed to start dronekit-sitl", error=str(e))
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
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
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
        if self.mode in ("dronekit", "dronekit-4") and self._sitl_instance:
            return self._stop_dronekit()
        elif self.mode == "docker":
            return self._stop_docker()
        elif self.mode == "local" and self._process:
            return self._stop_local()
        return True
    
    def _stop_dronekit(self) -> bool:
        """Stop dronekit-sitl."""
        if self._sitl_instance:
            log.info("stopping dronekit-sitl")
            self._sitl_instance.stop()
            log.info("dronekit-sitl stopped")
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
        if self.mode in ("dronekit", "dronekit-4") and self._sitl_instance:
            return True
        elif self.mode == "docker":
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
    parser.add_argument("--mode", default="dronekit-4", 
                       choices=["dronekit", "dronekit-4", "docker", "local", "external"])
    parser.add_argument("--connection", help="MAVLink connection string")
    parser.add_argument("--vehicle", default="copter", help="Vehicle type")
    parser.add_argument("--version", default="4.0", help="SITL version (e.g., 3.3, 4.0, 4.3)")
    parser.add_argument("--wait/--no-wait", default=True, help="Wait for ready")
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
