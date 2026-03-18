# Configuration Management

This document describes the configuration system for the drone platform.

## Overview

Configuration is managed using **Pydantic Settings**, providing:
- Type-safe configuration with validation
- Environment variable overrides
- TOML-based configuration files
- Hierarchical settings (default → file → env → CLI)

## Quick Start

### 1. Default Configuration (No Action Needed)

The system works out of the box with defaults:

```python
from interfaces.config import get_config

config = get_config()
print(config.vehicle.connection_string)  # tcp:127.0.0.1:5760
```

### 2. Using Config Files

Create a config file in `config/`:

```toml
# config/settings.local.toml
[vehicle]
connection_string = "tcp:3.83.48.196:5760"
force_arm = true

[logging]
level = "DEBUG"
```

Load it:

```python
config = get_config("config/settings.local.toml")
```

### 3. Using Environment Variables

Environment variables override config files:

```bash
export DRONE__VEHICLE__CONNECTION_STRING="tcp:3.83.48.196:5760"
export DRONE__VEHICLE__FORCE_ARM="true"
export DRONE__LOGGING__LEVEL="DEBUG"
```

Format: `DRONE__<SECTION>__<KEY>` (double underscore for nesting)

### 4. Using .env File

Create `.env` in repo root:

```bash
DRONE__VEHICLE__CONNECTION_STRING=tcp:3.83.48.196:5760
DRONE__LOGGING__LEVEL=DEBUG
```

Loaded automatically.

## Configuration Hierarchy

Settings are loaded in this order (later overrides earlier):

1. **Default values** (in code)
2. **TOML config file** (`config/settings.toml` or `$DRONE_CONFIG_FILE`)
3. **`.env` file** (in repo root)
4. **Environment variables** (`DRONE__*`)
5. **CLI arguments** (in application code)

## Configuration Sections

### `[vehicle]` - Vehicle Connection

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `backend` | string | `ardupilot_sitl` | `stub`, `ardupilot_sitl`, `ardupilot_serial` |
| `connection_string` | string | `tcp:127.0.0.1:5760` | MAVLink connection string |
| `force_arm` | bool | `false` | Bypass pre-arm checks (SITL only!) |
| `vehicle_type` | string | `copter` | `copter`, `plane`, `rover` |

#### `[vehicle.timeouts]` - Operation Timeouts

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `connection` | float | 30.0 | Connection timeout (seconds) |
| `arming` | float | 60.0 | Arming timeout |
| `takeoff` | float | 120.0 | Takeoff completion timeout |
| `mission` | float | 300.0 | Overall mission timeout |
| `mode_change` | float | 10.0 | Mode change timeout |

### `[simulation]` - SITL Settings

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `mode` | string | `local` | `local`, `docker`, `cloud`, `external` |
| `sitl_version` | string | `4.8` | ArduPilot version |
| `vehicle_type` | string | `copter` | Vehicle type for SITL |

#### `[simulation.gazebo]` - Gazebo Integration

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enabled` | bool | `false` | Enable Gazebo visualization |
| `world` | string | `basic_field` | World file name |
| `model` | string | `iris` | Drone model name |
| `physics_rtf` | float | 1.0 | Real-time factor (1.0 = real-time) |
| `gz_version` | string | `modern` | `classic` (Gazebo 11) or `modern` (Ignition) |

### `[logging]` - Logging Settings

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `level` | string | `INFO` | `DEBUG`, `INFO`, `WARNING`, `ERROR` |
| `format` | string | `structured` | `simple`, `structured`, `json` |

### `[mqtt]` - Split-Device Communication

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enabled` | bool | `false` | Enable MQTT for split topology |
| `host` | string | `localhost` | MQTT broker host |
| `port` | int | 1883 | MQTT broker port |
| `username` | string | `null` | Auth username |
| `password` | string | `null` | Auth password |

## Predefined Config Files

| File | Purpose |
|------|---------|
| `config/settings.toml` | Default local development |
| `config/settings.cloud.toml` | Cloud SITL on AWS EC2 |
| `config/settings.local.toml` | (gitignored) Your personal overrides |

## Examples

### Cloud SITL Configuration

```toml
# config/settings.cloud.toml
[vehicle]
connection_string = "tcp:3.83.48.196:5760"
force_arm = true

[simulation]
mode = "cloud"
```

Use with:

```bash
export DRONE_CONFIG_FILE=config/settings.cloud.toml
python3 -m autonomy.mission_manager --deployment deployments/full_sitl__cloud.yaml
```

### Local Gazebo Development

```toml
# config/settings.local.toml
[vehicle]
connection_string = "tcp:127.0.0.1:5760"

[simulation.gazebo]
enabled = true
world = "basic_field"
physics_rtf = 1.0
```

### CI/CD Headless Testing

```toml
[vehicle]
backend = "stub"

[simulation]
mode = "local"

[logging]
level = "WARNING"
format = "json"
```

## Migration from Hardcoded Values

If you're updating code that previously had hardcoded values:

### Before

```python
# adapters/vehicle_adapter/main.py
DEFAULT_SITL_CONNECTION = "tcp:127.0.0.1:5760"

def connect():
    connection_string = DEFAULT_SITL_CONNECTION
    # ...
```

### After

```python
from interfaces.config import get_config

def connect():
    config = get_config()
    connection_string = config.vehicle.connection_string
    # ...
```

## Troubleshooting

### Config not loading

Check file path:

```python
from interfaces.config import get_config
config = get_config("config/settings.cloud.toml")
```

### Environment variables not working

Verify format:

```bash
# Correct
export DRONE__VEHICLE__CONNECTION_STRING="tcp:..."

# Wrong (missing double underscore)
export DRONE_VEHICLE_CONNECTION_STRING="tcp:..."
```

### Type errors

All config values are validated. If you see:

```
ValidationError: Input should be 'copter', 'plane', or 'rover'
```

Check your `vehicle_type` value.

## See Also

- `interfaces/config.py` - Implementation
- `config/settings.toml` - Default config
- `docs/gazebo-integration.md` - Gazebo-specific config
