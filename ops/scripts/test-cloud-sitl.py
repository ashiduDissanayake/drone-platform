#!/usr/bin/env python3
"""Test connection to cloud SITL."""

from __future__ import annotations

import argparse
import sys
import time
from pymavlink import mavutil

def test_connection(connection_string: str, timeout: float = 30.0) -> bool:
    """Test connection to SITL and try to arm."""
    print(f"Connecting to {connection_string}...")
    
    try:
        master = mavutil.mavlink_connection(connection_string)
    except Exception as e:
        print(f"Failed to connect: {e}")
        return False
    
    print("Waiting for heartbeat...")
    if not master.wait_heartbeat(timeout=timeout):
        print("No heartbeat received")
        return False
    
    print(f"✓ Connected! System: {master.target_system}")
    
    # Request data
    master.mav.request_data_stream_send(
        master.target_system,
        master.target_component,
        mavutil.mavlink.MAV_DATA_STREAM_ALL,
        4, 1
    )
    
    # Wait for GPS
    print("\nWaiting for GPS (up to 60 seconds)...")
    start = time.time()
    gps_ready = False
    
    while time.time() - start < 60:
        master.recv_match(blocking=False)
        
        if 'GPS_RAW_INT' in master.messages:
            gps = master.messages['GPS_RAW_INT']
            if gps.fix_type >= 3:
                gps_ready = True
                print(f"✓ GPS ready! {gps.satellites_visible} satellites")
                break
            else:
                print(f"  GPS fix: {gps.fix_type}/3, sats: {gps.satellites_visible}  ", end="\r")
        
        time.sleep(1)
    
    if not gps_ready:
        print("\n⚠ GPS not ready, trying to arm anyway...")
    
    # Try to arm
    print("\n>>> Sending ARM command...")
    master.mav.command_long_send(
        master.target_system,
        master.target_component,
        mavutil.mavlink.MAV_CMD_COMPONENT_ARM_DISARM,
        0, 1, 0, 0, 0, 0, 0, 0
    )
    
    time.sleep(2)
    master.recv_match(blocking=False)
    
    armed = False
    if 'HEARTBEAT' in master.messages:
        hb = master.messages['HEARTBEAT']
        armed = hb.base_mode & mavutil.mavlink.MAV_MODE_FLAG_SAFETY_ARMED != 0
        mode = mavutil.mode_string_v10(hb)
        print(f"Status: Armed={armed}, Mode={mode}")
    
    if armed:
        print("\n🎉 SUCCESS! SITL is working correctly!")
        master.close()
        return True
    
    # Try force arm
    print("\n>>> Trying FORCE ARM...")
    master.mav.command_long_send(
        master.target_system,
        master.target_component,
        mavutil.mavlink.MAV_CMD_COMPONENT_ARM_DISARM,
        0, 1, 21196, 0, 0, 0, 0, 0
    )
    
    time.sleep(2)
    master.recv_match(blocking=False)
    
    if 'HEARTBEAT' in master.messages:
        hb = master.messages['HEARTBEAT']
        armed = hb.base_mode & mavutil.mavlink.MAV_MODE_FLAG_SAFETY_ARMED != 0
        print(f"After force: Armed={armed}")
    
    if armed:
        print("\n🎉 FORCE ARM SUCCESS!")
    else:
        print("\n❌ Could not arm. Check SITL status on cloud VM.")
    
    master.close()
    return armed

def main() -> int:
    parser = argparse.ArgumentParser(description="Test cloud SITL connection")
    parser.add_argument("--connection", default="tcp:127.0.0.1:5760",
                       help="MAVLink connection string")
    parser.add_argument("--timeout", type=float, default=30.0,
                       help="Connection timeout")
    args = parser.parse_args()
    
    success = test_connection(args.connection, args.timeout)
    return 0 if success else 1

if __name__ == "__main__":
    raise SystemExit(main())
