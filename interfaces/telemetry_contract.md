# Telemetry Contract (V1)

Defines normalized telemetry stream consumed by autonomy and operators.

## Minimum payload
- timestamp
- vehicle_id
- position (lat, lon, alt)
- attitude (roll, pitch, yaw)
- velocity (x, y, z)
- battery (voltage, percent)
- health flags

## Transport constraints
- Must support distributed deployment where producer and consumer run on different devices.
