"""Structured logging utility with tagged output for drone-platform.

This module provides consistent, tag-based logging across all platform components.
Tags help identify the source component when running distributed deployments.

Usage:
    from interfaces.logging import get_logger
    
    log = get_logger("mission-manager")
    log.info("starting mission", mission="takeoff_land")
    log.warning("battery low", percent=15)
    log.error("connection failed", error="timeout")
    log.debug("received telemetry", position={"lat": -35.36, "lon": 149.16})
"""

from __future__ import annotations

import sys
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any


# ANSI color codes (disabled if not tty)
COLORS = {
    "reset": "\033[0m",
    "dim": "\033[2m",
    "bold": "\033[1m",
    # Component colors
    "mission": "\033[36m",      # Cyan
    "vehicle": "\033[32m",      # Green  
    "world": "\033[34m",        # Blue
    "telemetry": "\033[35m",    # Magenta
    "infra": "\033[33m",        # Yellow
    # Level colors
    "debug": "\033[2m",         # Dim
    "info": "\033[0m",          # Normal
    "warning": "\033[33m",      # Yellow
    "error": "\033[31m",        # Red
}


@dataclass
class LogEntry:
    """A structured log entry."""
    timestamp: str
    component: str
    level: str
    message: str
    fields: dict[str, Any]


class TaggedLogger:
    """Logger that outputs tagged, structured log lines.
    
    Output format:
        [TIMESTAMP] [COMPONENT] [LEVEL] message key=value key2=value2
    
    Example:
        [14:17:26.123] [mission-manager] [INFO] starting mission name=takeoff_land
    """
    
    def __init__(self, component: str, use_colors: bool | None = None) -> None:
        """Initialize logger for a component.
        
        Args:
            component: Component name (e.g., "mission-manager", "vehicle-adapter")
            use_colors: Enable ANSI colors. Auto-detected if None.
        """
        self.component = component
        if use_colors is None:
            use_colors = sys.stderr.isatty()
        self.use_colors = use_colors
    
    def _color(self, name: str, text: str) -> str:
        """Apply color to text if colors enabled."""
        if not self.use_colors:
            return text
        code = COLORS.get(name, "")
        reset = COLORS["reset"] if code else ""
        return f"{code}{text}{reset}"
    
    def _format_fields(self, fields: dict[str, Any]) -> str:
        """Format extra fields as key=value pairs."""
        if not fields:
            return ""
        parts = []
        for key, value in fields.items():
            if isinstance(value, str) and " " in value:
                parts.append(f'{key}="{value}"')
            else:
                parts.append(f"{key}={value}")
        return " " + " ".join(parts)
    
    def _log(self, level: str, message: str, **fields: Any) -> None:
        """Emit a log entry."""
        now = datetime.now(timezone.utc)
        timestamp = now.strftime("%H:%M:%S") + f".{now.microsecond // 1000:03d}"
        
        # Determine component color
        comp_color = "mission"
        if "vehicle" in self.component:
            comp_color = "vehicle"
        elif "world" in self.component:
            comp_color = "world"
        elif "telemetry" in self.component:
            comp_color = "telemetry"
        elif "infra" in self.component or "ansible" in self.component:
            comp_color = "infra"
        
        # Build the tag parts
        ts_tag = self._color("dim", f"[{timestamp}]")
        comp_tag = self._color(comp_color, f"[{self.component}]")
        level_tag = self._color(level.lower(), f"[{level}]")
        
        # Format extra fields
        field_str = ""
        if fields:
            field_parts = []
            for key, value in fields.items():
                if isinstance(value, float):
                    field_parts.append(f"{key}={value:.2f}")
                elif isinstance(value, bool):
                    field_parts.append(f"{key}={'true' if value else 'false'}")
                elif isinstance(value, dict):
                    # Compact dict representation
                    dict_str = ",".join(f"{k}:{v}" for k, v in value.items())
                    field_parts.append(f"{key}={{{dict_str}}}")
                else:
                    val_str = str(value)
                    if " " in val_str or "=" in val_str:
                        field_parts.append(f'{key}="{val_str}"')
                    else:
                        field_parts.append(f"{key}={val_str}")
            field_str = " " + " ".join(field_parts)
        
        line = f"{ts_tag} {comp_tag} {level_tag} {message}{field_str}"
        
        if level in ("ERROR", "CRITICAL"):
            print(line, file=sys.stderr)
        else:
            print(line)
    
    def debug(self, message: str, **fields: Any) -> None:
        """Log debug message."""
        self._log("DEBUG", message, **fields)
    
    def info(self, message: str, **fields: Any) -> None:
        """Log info message."""
        self._log("INFO", message, **fields)
    
    def warning(self, message: str, **fields: Any) -> None:
        """Log warning message."""
        self._log("WARNING", message, **fields)
    
    def error(self, message: str, **fields: Any) -> None:
        """Log error message."""
        self._log("ERROR", message, **fields)


# Module-level cache of loggers
_loggers: dict[str, TaggedLogger] = {}


def get_logger(component: str) -> TaggedLogger:
    """Get or create a tagged logger for a component.
    
    Args:
        component: Component name used in tags (e.g., "mission-manager")
        
    Returns:
        TaggedLogger instance for the component
        
    Example:
        >>> log = get_logger("vehicle-adapter")
        >>> log.info("connected", backend="ardupilot_sitl")
        [14:17:26.123] [vehicle-adapter] [INFO] connected backend=ardupilot_sitl
    """
    if component not in _loggers:
        _loggers[component] = TaggedLogger(component)
    return _loggers[component]


def clear_loggers() -> None:
    """Clear logger cache (useful for testing)."""
    _loggers.clear()
