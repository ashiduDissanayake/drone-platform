"""Vehicle adapter with MAVLink integration for ArduPilot.

Translates high-level mission commands to MAVLink protocol.
Supports both real hardware and SITL simulation.
"""

from __future__ import annotations

import argparse
import json
import time
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any

from interfaces.config import get_config
from interfaces.logging import get_logger


log = get_logger("vehicle-adapter")

# Legacy defaults (used only when config is not available)
_FALLBACK_SITL_CONNECTION = "tcp:127.0.0.1:5760"
_FALLBACK_SERIAL_CONNECTION = "/dev/ttyACM0"


@dataclass
class VehicleCommand:
    """A command to be executed by the vehicle."""
    name: str
    payload: dict[str, Any]


class MAVLinkConnection:
    """Manages MAVLink connection to vehicle."""
    
    def __init__(self, connection_string: str, timeout: float = 30.0) -> None:
        self.connection_string = connection_string
        self.timeout = timeout
        self._master: Any = None
        self._connected = False
        
    def connect(self) -> bool:
        """Establish MAVLink connection."""
        try:
            from pymavlink import mavutil
        except ImportError as e:
            log.error("pymavlink not installed", error=str(e))
            return False
        
        if self._connected:
            return True
        
        log.info("connecting to vehicle", connection=self.connection_string)
        
        try:
            self._master = mavutil.mavlink_connection(self.connection_string)
            heartbeat = self._master.wait_heartbeat(timeout=self.timeout)
            if heartbeat is None:
                log.error("did not receive HEARTBEAT within timeout")
                self._master.close()
                self._master = None
                return False
            self._connected = True
            
            # Request data stream
            self._master.mav.request_data_stream_send(
                self._master.target_system,
                self._master.target_component,
                mavutil.mavlink.MAV_DATA_STREAM_ALL,
                4,  # Rate (Hz)
                1,  # Enable
            )
            
            log.info("connected to vehicle",
                    system=self._master.target_system,
                    component=self._master.target_component,
                    vehicle_type=mavutil.mode_string_v10(heartbeat))
            return True
            
        except Exception as e:
            log.error("connection failed", error=str(e))
            return False
    
    def disconnect(self) -> None:
        """Close MAVLink connection."""
        if self._master:
            self._master.close()
            self._connected = False
            log.info("disconnected from vehicle")
    
    def send_command_long(
        self,
        command: int,
        confirmation: int = 0,
        param1: float = 0,
        param2: float = 0,
        param3: float = 0,
        param4: float = 0,
        param5: float = 0,
        param6: float = 0,
        param7: float = 0,
    ) -> None:
        """Send COMMAND_LONG message."""
        if not self._connected:
            raise RuntimeError("not connected")
        
        self._master.mav.command_long_send(
            self._master.target_system,
            self._master.target_component,
            command,
            confirmation,
            param1, param2, param3, param4, param5, param6, param7,
        )
    
    def set_mode(self, mode: str, wait: bool = True, timeout: float = 3.0) -> bool:
        """Set vehicle flight mode."""
        from pymavlink import mavutil
        
        mode_id = self._master.mode_mapping().get(mode)
        if mode_id is None:
            log.error("unknown mode", mode=mode, available=list(self._master.mode_mapping().keys()))
            return False
        
        # Check if already in desired mode
        if 'HEARTBEAT' in self._master.messages:
            current_mode_id = self._master.messages['HEARTBEAT'].custom_mode
            if current_mode_id == mode_id:
                log.debug("already in mode", mode=mode)
                return True
        
        # Use COMMAND_LONG with DO_SET_MODE (works better with SITL 4.8)
        self.send_command_long(
            mavutil.mavlink.MAV_CMD_DO_SET_MODE,
            param1=mavutil.mavlink.MAV_MODE_FLAG_CUSTOM_MODE_ENABLED,
            param2=mode_id,
        )
        log.info("mode change requested", mode=mode, mode_id=mode_id)
        
        if not wait:
            return True
        
        # Wait for mode change to take effect (verified via HEARTBEAT)
        start = time.time()
        while time.time() - start < timeout:
            msg = self._master.recv_match(blocking=False)
            if msg and msg.get_type() == 'HEARTBEAT':
                # Check if mode matches (custom_mode contains the mode ID)
                if msg.custom_mode == mode_id:
                    log.info("mode change confirmed", mode=mode)
                    return True
            time.sleep(0.05)
        
        log.warning("mode change timeout", mode=mode, waited=f"{time.time()-start:.1f}s")
        return False
    
    def set_rc_override(self, channel: int, pwm: int) -> bool:
        """Set RC channel override (for simulation)."""
        from pymavlink import mavutil
        
        # Create RC_CHANNELS_OVERRIDE message
        # Channel 3 is throttle (typically)
        self._master.mav.rc_channels_override_send(
            self._master.target_system,
            self._master.target_component,
            0, 0, pwm, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        )
        log.info("RC override sent", channel=channel, pwm=pwm)
        return True
    
    def arm(self, force: bool = False) -> bool:
        """Arm the vehicle."""
        from pymavlink import mavutil
        
        # Set throttle to minimum before arming (required for SITL 4.8)
        log.info("setting throttle to minimum for arming")
        self.set_rc_override(3, 1000)  # Throttle channel = 1000 (minimum)
        
        # Small delay for RC to take effect
        import time
        time.sleep(0.5)
        
        self.send_command_long(
            mavutil.mavlink.MAV_CMD_COMPONENT_ARM_DISARM,
            param1=1,  # Arm
            param2=21196 if force else 0,  # Force arm
        )
        log.info("arm command sent", force=force)
        
        # Clear message backlog and look for ACK or armed status
        # SITL 4.8 sends lots of messages, ACK may be buried in queue
        ack_result = None
        start_time = time.time()
        
        while time.time() - start_time < 3.0:  # Wait up to 3 seconds
            msg = self._master.recv_match(blocking=False)
            if msg is None:
                time.sleep(0.05)
                continue
            
            # Check for COMMAND_ACK
            if msg.get_type() == 'COMMAND_ACK':
                if msg.command == mavutil.mavlink.MAV_CMD_COMPONENT_ARM_DISARM:
                    ack_result = msg.result
                    log.info("arm ACK received", result=ack_result)
                    if ack_result != 0:
                        log.error("arm command rejected", result=ack_result)
                        return False
                    # Command accepted, now wait for HEARTBEAT to confirm armed state
                    break
        
        # Even if ACK was received, verify via HEARTBEAT
        # (sometimes SITL accepts but doesn't arm immediately)
        # Process for up to 3 seconds looking for HEARTBEAT with armed flag
        start_check = time.time()
        while time.time() - start_check < 3.0:
            msg = self._master.recv_match(blocking=False)
            if msg and msg.get_type() == 'HEARTBEAT':
                armed = msg.base_mode & mavutil.mavlink.MAV_MODE_FLAG_SAFETY_ARMED != 0
                if armed:
                    log.info("vehicle is now ARMED")
                    return True
            time.sleep(0.05)
        
        log.error("vehicle failed to arm")
        return False
    
    def disarm(self) -> bool:
        """Disarm the vehicle."""
        from pymavlink import mavutil
        
        self.send_command_long(
            mavutil.mavlink.MAV_CMD_COMPONENT_ARM_DISARM,
            param1=0,  # Disarm
        )
        log.info("disarm command sent")
        return True
    
    def takeoff(self, altitude: float) -> bool:
        """Command takeoff to specified altitude."""
        from pymavlink import mavutil
        
        # First ensure in guided mode
        self.set_mode("GUIDED")
        
        self.send_command_long(
            mavutil.mavlink.MAV_CMD_NAV_TAKEOFF,
            param7=altitude,
        )
        log.info("takeoff command sent", altitude_m=altitude)
        return True
    
    def goto_waypoint(self, lat: float, lon: float, alt: float) -> bool:
        """Fly to global position."""
        from pymavlink import mavutil
        
        # Convert to integers (degrees * 1e7)
        lat_int = int(lat * 1e7)
        lon_int = int(lon * 1e7)
        
        self._master.mav.set_position_target_global_int_send(
            0,  # System time (0 for now)
            self._master.target_system,
            self._master.target_component,
            mavutil.mavlink.MAV_FRAME_GLOBAL_RELATIVE_ALT,
            0b0000111111111000,  # Type mask
            lat_int,
            lon_int,
            alt,
            0, 0, 0,  # Velocities
            0, 0, 0,  # Accels
            0, 0,     # Yaw
        )
        log.info("goto waypoint command sent", lat=lat, lon=lon, alt_m=alt)
        return True
    
    def land(self) -> bool:
        """Command immediate landing."""
        from pymavlink import mavutil
        
        self.set_mode("LAND")
        log.info("land command sent")
        return True
    
    def get_telemetry(self) -> dict[str, Any]:
        """Get current telemetry."""
        from pymavlink import mavutil
        
        # Process any pending messages
        self._master.recv_match(blocking=False)
        
        # Get latest messages
        position = {"lat": 0.0, "lon": 0.0, "alt_m": 0.0}
        velocity = {"vx_mps": 0.0, "vy_mps": 0.0, "vz_mps": 0.0}
        battery = {"voltage_v": 0.0, "percent": 0.0}
        state = {"armed": False, "mode": "UNKNOWN", "health_flags": {}}
        
        # Global position
        if 'GLOBAL_POSITION_INT' in self._master.messages:
            msg = self._master.messages['GLOBAL_POSITION_INT']
            position["lat"] = msg.lat / 1e7
            position["lon"] = msg.lon / 1e7
            position["alt_m"] = msg.relative_alt / 1000.0  # mm to m
            velocity["vx_mps"] = msg.vx / 100.0  # cm/s to m/s
            velocity["vy_mps"] = msg.vy / 100.0
            velocity["vz_mps"] = msg.vz / 100.0
        
        # Battery
        if 'SYS_STATUS' in self._master.messages:
            msg = self._master.messages['SYS_STATUS']
            battery["voltage_v"] = msg.voltage_battery / 1000.0  # mV to V
            battery["percent"] = msg.battery_remaining
        
        # GPS health
        gps_ok = None
        if 'GPS_RAW_INT' in self._master.messages:
            gps_msg = self._master.messages['GPS_RAW_INT']
            try:
                fix_type = gps_msg.fix_type
            except AttributeError:
                fix_type = None
            if fix_type is not None and fix_type >= 3:
                gps_ok = True
            else:
                gps_ok = False
        
        # State
        if 'HEARTBEAT' in self._master.messages:
            msg = self._master.messages['HEARTBEAT']
            state["armed"] = msg.base_mode & mavutil.mavlink.MAV_MODE_FLAG_SAFETY_ARMED != 0
            state["mode"] = mavutil.mode_string_v10(msg)
            state["health_flags"] = {
                "gps_ok": gps_ok,
                "link_ok": True,
            }
        
        return {
            "position": position,
            "velocity": velocity,
            "battery": battery,
            "state": state,
        }
    
    def wait_for_ready(
        self,
        timeout: float = 60.0,
        require_gps: bool = True,
        require_ekf: bool = True,
    ) -> bool:
        """Wait for vehicle to be ready for flight.
        
        Args:
            timeout: Maximum time to wait in seconds
            require_gps: Wait for GPS 3D fix
            require_ekf: Wait for EKF (attitude estimator) ready
            
        Returns:
            True if vehicle is ready
        """
        from pymavlink import mavutil
        
        log.info("waiting for vehicle ready",
                timeout=timeout,
                require_gps=require_gps,
                require_ekf=require_ekf)
        
        start = time.time()
        last_status_log = 0
        gps_ok = not require_gps  # Initialize based on requirements
        ekf_ok = not require_ekf
        
        while time.time() - start < timeout:
            # Process messages
            self._master.recv_match(blocking=False)
            
            # Check GPS status (once OK, stays OK)
            if require_gps and not gps_ok and 'GPS_RAW_INT' in self._master.messages:
                gps_msg = self._master.messages['GPS_RAW_INT']
                # GPS_FIX_TYPE_3D_FIX = 3
                gps_ok = gps_msg.fix_type >= 3
            
            # Check EKF status (if available - older SITL may not send this)
            if require_ekf and not ekf_ok:
                if 'EKF_STATUS_REPORT' in self._master.messages:
                    ekf_msg = self._master.messages['EKF_STATUS_REPORT']
                    flags = ekf_msg.flags
                    ekf_ok = flags > 0
                elif gps_ok:
                    # No EKF message but GPS is ready - for older SITL, this is sufficient
                    ekf_ok = True
            
            # Check if ready
            if gps_ok and ekf_ok:
                elapsed = time.time() - start
                log.info("vehicle ready", elapsed=f"{elapsed:.1f}s")
                return True
            
            # Log status every 5 seconds
            if time.time() - last_status_log >= 5:
                elapsed = time.time() - start
                status = []
                if require_gps:
                    status.append(f"gps={'OK' if gps_ok else 'waiting'}")
                if require_ekf:
                    status.append(f"ekf={'OK' if ekf_ok else 'waiting'}")
                log.info(f"waiting... ({', '.join(status)})", elapsed=f"{elapsed:.1f}s")
                last_status_log = time.time()
            
            time.sleep(0.5)
        
        log.error("timeout waiting for vehicle ready")
        return False
    
    def check_preflight(self) -> dict[str, Any]:
        """Check pre-flight status.
        
        Returns:
            Dict with pre-arm check results
        """
        from pymavlink import mavutil
        
        self._master.recv_match(blocking=False)
        
        result = {
            "gps_fix": False,
            "gps_sats": 0,
            "ekf_ready": False,
            "battery_ok": False,
            "armed": False,
            "mode": "UNKNOWN",
        }
        
        # GPS
        if 'GPS_RAW_INT' in self._master.messages:
            gps = self._master.messages['GPS_RAW_INT']
            result["gps_fix"] = gps.fix_type >= 3
            result["gps_sats"] = gps.satellites_visible
        
        # EKF
        if 'EKF_STATUS_REPORT' in self._master.messages:
            ekf = self._master.messages['EKF_STATUS_REPORT']
            result["ekf_ready"] = bool(ekf.flags & 9)  # Attitude + Pos HORIZ
        
        # Battery
        if 'SYS_STATUS' in self._master.messages:
            batt = self._master.messages['SYS_STATUS']
            result["battery_ok"] = batt.battery_remaining > 20
        
        # State
        if 'HEARTBEAT' in self._master.messages:
            hb = self._master.messages['HEARTBEAT']
            result["armed"] = hb.base_mode & mavutil.mavlink.MAV_MODE_FLAG_SAFETY_ARMED != 0
            result["mode"] = mavutil.mode_string_v10(hb)
        
        return result


class VehicleAdapter:
    """High-level vehicle adapter that manages MAVLink connection.
    
    Backends:
    - ardupilot_sitl: Connect to ArduPilot SITL via TCP/UDP
    - ardupilot_serial: Connect to real hardware via serial
    - stub: Fake telemetry for testing (no connection)
    """

    def __init__(
        self,
        backend: str | None = None,
        connection_string: str | None = None,
        auto_connect: bool = True,
        config = None,
    ) -> None:
        # Load config if not provided
        self._config = config or get_config()
        
        # Determine backend (arg > config > default)
        self.backend = backend or self._config.vehicle.backend
        self._connection: MAVLinkConnection | None = None
        
        # Determine connection string
        if connection_string:
            conn_str = connection_string
        elif self.backend == "ardupilot_sitl":
            conn_str = self._config.vehicle.connection_string
        elif self.backend == "ardupilot_serial":
            conn_str = _FALLBACK_SERIAL_CONNECTION
        else:
            conn_str = ""
        
        if self.backend != "stub" and conn_str:
            self._connection = MAVLinkConnection(
                conn_str,
                timeout=self._config.vehicle.timeouts.connection
            )
        
        if auto_connect and self._connection:
            self._connect()
        
        log.info("adapter created", backend=self.backend, connection=conn_str or "none")

    def _connect(self) -> bool:
        """Connect to vehicle."""
        if self._connection:
            return self._connection.connect()
        return True
    
    def is_connected(self) -> bool:
        """Check if vehicle is connected."""
        return self._connection is not None and self._connection._connected
    
    def wait_for_ready(self, timeout: float | None = None) -> bool:
        """Wait for vehicle to be ready for flight.
        
        Args:
            timeout: Override timeout in seconds. Uses config default if None.
        """
        if not self.is_connected():
            log.error("cannot wait for ready - not connected")
            return False
        
        if self._connection:
            actual_timeout = timeout or self._config.vehicle.timeouts.connection
            return self._connection.wait_for_ready(timeout=actual_timeout)
        return True
    
    def check_preflight(self) -> dict[str, Any]:
        """Check pre-flight status."""
        if self._connection:
            return self._connection.check_preflight()
        return {"stub": True}

    def execute(self, command: VehicleCommand) -> dict[str, Any]:
        """Execute a command and return telemetry.
        
        Args:
            command: The VehicleCommand to execute
            
        Returns:
            Telemetry dict conforming to Vehicle Contract v1
        """
        vehicle_id = str(command.payload.get("vehicle_id", "vehicle-1"))
        
        if self.backend == "stub":
            return self._execute_stub(command, vehicle_id)
        
        # Ensure connected
        if self._connection and not self._connection._connected:
            if not self._connection.connect():
                raise RuntimeError("failed to connect to vehicle")
        
        # Execute command
        cmd = command.name
        payload = command.payload
        
        log.info("executing command", command=cmd, vehicle=vehicle_id)
        
        if cmd == "arm":
            force = payload.get("force", False)
            self._connection.arm(force=force)
        
        elif cmd == "disarm":
            self._connection.disarm()
        
        elif cmd == "takeoff":
            alt = float(payload.get("target_altitude_m", 10.0))
            self._connection.takeoff(alt)
        
        elif cmd == "goto_waypoint":
            lat = float(payload.get("lat", 0))
            lon = float(payload.get("lon", 0))
            alt = float(payload.get("alt", 10))
            self._connection.goto_waypoint(lat, lon, alt)
        
        elif cmd == "land":
            self._connection.land()
        
        elif cmd == "set_mode":
            mode = payload.get("mode", "STABILIZE")
            self._connection.set_mode(mode)
        
        else:
            log.warning("unknown command", command=cmd)
        
        # Small delay for command to take effect
        time.sleep(0.1)
        
        # Get telemetry
        telemetry = self._connection.get_telemetry()
        
        return {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "vehicle_id": vehicle_id,
            "data": telemetry,
        }

    def _execute_stub(self, command: VehicleCommand, vehicle_id: str) -> dict[str, Any]:
        """Execute stub command (fake telemetry)."""
        log.debug("using stub backend")
        
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

    def disconnect(self) -> None:
        """Disconnect from vehicle."""
        if self._connection:
            self._connection.disconnect()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run vehicle adapter")
    parser.add_argument("--backend", default="ardupilot_sitl",
                       choices=["ardupilot_sitl", "ardupilot_serial", "stub"])
    parser.add_argument("--connection", help="MAVLink connection string (overrides backend default)")
    parser.add_argument("--command", default="arm",
                       help="command name (arm/takeoff/goto_waypoint/land/disarm)")
    parser.add_argument(
        "--payload",
        default='{"vehicle_id": "vehicle-1"}',
        help="JSON payload for the command",
    )
    parser.add_argument("--verbose", "-v", action="store_true",
                       help="Enable debug logging")
    parser.add_argument("--wait-ready", action="store_true",
                       help="Wait for vehicle ready before executing command")
    return parser.parse_args()


def main() -> int:
    import logging
    args = parse_args()
    
    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)
    
    try:
        payload = json.loads(args.payload)
    except json.JSONDecodeError as err:
        log.error("invalid payload JSON", error=str(err))
        return 1

    adapter = VehicleAdapter(
        backend=args.backend,
        connection_string=args.connection,
        auto_connect=True,
    )
    
    # Wait for ready if requested
    if args.wait_ready:
        log.info("waiting for vehicle ready...")
        if not adapter.wait_for_ready(timeout=60.0):
            log.error("vehicle not ready")
            return 1
    
    try:
        telemetry = adapter.execute(VehicleCommand(name=args.command, payload=payload))
    except Exception as e:
        log.error("command failed", error=str(e))
        return 1
    finally:
        adapter.disconnect()
    
    log.info("telemetry generated", vehicle=telemetry["vehicle_id"])
    print(json.dumps(telemetry, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
