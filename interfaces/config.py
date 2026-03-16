"""Configuration management using Pydantic Settings.

Provides type-safe configuration loading from TOML files,
environment variables, and .env files.

Usage:
    from interfaces.config import get_config
    
    config = get_config()
    print(config.vehicle.connection_string)
    print(config.simulation.mode)
"""

from __future__ import annotations

from functools import lru_cache
from pathlib import Path
from typing import Literal

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


# Repository root directory
REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CONFIG_DIR = REPO_ROOT / "config"


class VehicleTimeouts(BaseSettings):
    """Timeout configuration for vehicle operations."""
    
    model_config = SettingsConfigDict(extra="ignore")
    
    connection: float = 30.0
    arming: float = 60.0
    takeoff: float = 120.0
    mission: float = 300.0
    mode_change: float = 10.0


class VehicleConfig(BaseSettings):
    """Vehicle/adapter configuration."""
    
    model_config = SettingsConfigDict(extra="ignore")
    
    backend: Literal["stub", "ardupilot_sitl", "ardupilot_serial"] = "ardupilot_sitl"
    connection_string: str = "tcp:127.0.0.1:5760"
    force_arm: bool = False
    vehicle_type: Literal["copter", "plane", "rover"] = "copter"
    
    timeouts: VehicleTimeouts = Field(default_factory=VehicleTimeouts)


class SimulationGazebo(BaseSettings):
    """Gazebo simulation configuration."""
    
    model_config = SettingsConfigDict(extra="ignore")
    
    enabled: bool = False
    world: str = "basic_field"
    model: str = "iris"
    physics_rtf: float = 1.0  # Real-time factor
    gz_version: Literal["classic", "modern"] = "modern"


class SimulationConfig(BaseSettings):
    """SITL simulation configuration."""
    
    model_config = SettingsConfigDict(extra="ignore")
    
    mode: Literal["local", "docker", "cloud", "external"] = "local"
    sitl_version: str = "4.8"
    vehicle_type: Literal["copter", "plane", "rover"] = "copter"
    
    gazebo: SimulationGazebo = Field(default_factory=SimulationGazebo)


class LoggingConfig(BaseSettings):
    """Logging configuration."""
    
    model_config = SettingsConfigDict(extra="ignore")
    
    level: Literal["DEBUG", "INFO", "WARNING", "ERROR"] = "INFO"
    format: Literal["simple", "structured", "json"] = "structured"


class MqttConfig(BaseSettings):
    """MQTT configuration for split-device topology."""
    
    model_config = SettingsConfigDict(extra="ignore")
    
    enabled: bool = False
    host: str = "localhost"
    port: int = 1883
    username: str | None = None
    password: str | None = None


class DronePlatformConfig(BaseSettings):
    """Root configuration for the drone platform.
    
    Loads from (in order of priority):
    1. Environment variables (DRONE__VEHICLE__CONNECTION_STRING)
    2. .env file in repo root
    3. config/settings.toml (or file specified by DRONE_CONFIG_FILE)
    4. Default values
    """
    
    model_config = SettingsConfigDict(
        env_prefix="DRONE__",
        env_nested_delimiter="__",
        env_file=REPO_ROOT / ".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )
    
    vehicle: VehicleConfig = Field(default_factory=VehicleConfig)
    simulation: SimulationConfig = Field(default_factory=SimulationConfig)
    logging: LoggingConfig = Field(default_factory=LoggingConfig)
    mqtt: MqttConfig = Field(default_factory=MqttConfig)


# Global config instance cache
_config_instance: DronePlatformConfig | None = None


def _get_env_overrides() -> dict[str, Any]:
    """Get configuration overrides from environment variables.
    
    Converts DRONE__SECTION__KEY=value to nested dict.
    """
    import os
    
    overrides: dict[str, Any] = {}
    prefix = "DRONE__"
    
    for key, value in os.environ.items():
        if not key.startswith(prefix):
            continue
        
        # Parse DRONE__SECTION__SUBSECTION__KEY
        parts = key[len(prefix):].lower().split("__")
        
        # Navigate/create nested dict structure
        current = overrides
        for part in parts[:-1]:
            if part not in current:
                current[part] = {}
            current = current[part]
        
        # Set the value (try to parse as int/float/bool)
        final_key = parts[-1]
        current[final_key] = _parse_env_value(value)
    
    return overrides


def _parse_env_value(value: str) -> Any:
    """Parse environment variable value to appropriate type."""
    # Boolean values
    if value.lower() in ("true", "1", "yes", "on"):
        return True
    if value.lower() in ("false", "0", "no", "off"):
        return False
    
    # Integer
    try:
        return int(value)
    except ValueError:
        pass
    
    # Float
    try:
        return float(value)
    except ValueError:
        pass
    
    # String (default)
    return value


def _deep_merge(base: dict[str, Any], override: dict[str, Any]) -> dict[str, Any]:
    """Deep merge override into base dict."""
    result = base.copy()
    for key, value in override.items():
        if key in result and isinstance(result[key], dict) and isinstance(value, dict):
            result[key] = _deep_merge(result[key], value)
        else:
            result[key] = value
    return result


def get_config(
    config_file: Path | str | None = None,
    reload: bool = False,
) -> DronePlatformConfig:
    """Get the global configuration instance.
    
    Loads configuration with the following priority (highest first):
    1. Environment variables (DRONE__*)
    2. TOML config file (if specified via DRONE_CONFIG_FILE or config_file arg)
    3. Default values
    
    Args:
        config_file: Path to TOML config file. If None, uses DRONE_CONFIG_FILE
                     env var or defaults only
        reload: Force reload from disk
        
    Returns:
        DronePlatformConfig instance
        
    Example:
        >>> config = get_config()
        >>> print(config.vehicle.connection_string)
        'tcp:127.0.0.1:5760'
        
        >>> config = get_config("config/cloud.toml")
        >>> print(config.simulation.mode)
        'cloud'
    """
    global _config_instance
    
    if _config_instance is not None and not reload:
        return _config_instance
    
    # Determine config file path - only use if explicitly specified
    toml_data: dict[str, Any] = {}
    if config_file is not None:
        config_file = Path(config_file)
    else:
        # Check for DRONE_CONFIG_FILE env var
        config_file_env = __import__("os").environ.get("DRONE_CONFIG_FILE")
        if config_file_env:
            config_file = Path(config_file_env)
    
    # Load from TOML if file exists
    if config_file is not None and config_file.exists():
        import tomllib
        with open(config_file, "rb") as f:
            toml_data = tomllib.load(f)
    
    # Get environment variable overrides
    env_overrides = _get_env_overrides()
    
    # Merge: TOML data first, then env overrides
    merged_data = _deep_merge(toml_data, env_overrides)
    
    # Create config instance
    _config_instance = DronePlatformConfig(**merged_data)
    
    return _config_instance


def clear_config_cache() -> None:
    """Clear the global config cache.
    
    Useful for testing or when config file changes.
    """
    global _config_instance
    _config_instance = None


# CLI entry point for testing
if __name__ == "__main__":
    import json
    
    config = get_config()
    print(json.dumps(config.model_dump(), indent=2, default=str))
