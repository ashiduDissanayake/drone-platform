# ADR 001: Configuration Management

**Status:** Proposed  
**Date:** 2026-03-15  
**Deciders:** [Team members to review]

---

## Context

Currently, connection strings, URLs, and deployment parameters are hardcoded throughout the codebase:

```python
# adapters/vehicle_adapter/main.py (current)
DEFAULT_SITL_CONNECTION = "tcp:127.0.0.1:5760"

# ops/scripts/test-cloud-sitl.py (current)
master = mavutil.mavlink_connection('tcp:54.152.238.66:5760')
```

Problems:
- Must edit code to change deployment target
- No separation between dev/staging/production
- Risk of committing sensitive IPs/URLs
- Difficult for new developers to configure

---

## Decision Drivers

1. **Environment-specific configs** - Dev (local), Staging (cloud), Prod (real drones)
2. **No code changes for deployment** - Config should be external
3. **Type safety** - Validate config at startup
4. **Secret management** - Don't commit sensitive data
5. **Ease of use** - Simple for developers to understand

---

## Options Considered

### Option 1: TOML Files

```toml
# config/deployment.toml
[vehicle]
backend = "ardupilot_sitl"
connection_string = "tcp:127.0.0.1:5760"

[vehicle.timeouts]
connection = 30.0
arming = 60.0
```

**Pros:**
- Human-readable, standard format
- Supports comments
- Good Python support (toml library)

**Cons:**
- Another file format to learn
- No built-in env var interpolation

### Option 2: YAML Files

```yaml
# config/deployment.yaml
vehicle:
  backend: ardupilot_sitl
  connection_string: tcp:127.0.0.1:5760
  timeouts:
    connection: 30.0
```

**Pros:**
- Very widely used
- Supports anchors/references

**Cons:**
- Whitespace-sensitive (error-prone)
- Overkill for simple config

### Option 3: Pydantic Settings (Recommended)

```python
# config/settings.py
from pydantic import Field
from pydantic_settings import BaseSettings

class VehicleSettings(BaseSettings):
    backend: str = "ardupilot_sitl"
    connection_string: str = "tcp:127.0.0.1:5760"
    timeout_connection: float = 30.0
    
    class Config:
        env_prefix = "DRONE_"
        toml_file = "config/deployment.toml"
```

**Pros:**
- Type-safe (validation at import)
- Env var override (DRONE_BACKEND=stub)
- File + environment hybrid
- Auto-completion in IDEs

**Cons:**
- Additional dependency (pydantic-settings)
- More complex setup

### Option 4: Python Dataclasses

```python
# config/deployment.py
from dataclasses import dataclass

@dataclass
class DeploymentConfig:
    backend: str = "ardupilot_sitl"
    connection_string: str = "tcp:127.0.0.1:5760"
```

**Pros:**
- No parsing needed
- Full Python flexibility
- Type-safe

**Cons:**
- Not truly external config
- Requires Python knowledge to edit

---

## Recommendation

**Use Option 3: Pydantic Settings**

With this pattern:
1. Default values in code for development
2. Override via `config/deployment.toml` for specific environments
3. Override via environment variables for secrets/CI/CD

Example usage:
```python
from config import settings

# Uses priority: env vars > toml file > defaults
adapter = VehicleAdapter(
    backend=settings.vehicle.backend,
    connection=settings.vehicle.connection_string
)
```

---

## Implementation Plan

1. Add `pydantic-settings` to requirements
2. Create `interfaces/config.py` with Pydantic models
3. Create `config/` directory with:
   - `default.toml` - Sensible defaults
   - `dev.toml` - Local development overrides
   - `cloud.toml` - Cloud SITL configuration
   - `.gitignore` - Ignore local overrides
4. Refactor all hardcoded values to use settings
5. Document configuration options

---

## Consequences

### Positive
- Single source of truth for configuration
- Environment-specific deployments without code changes
- Type-safe configuration with validation
- Easy for ops to configure without Python knowledge

### Negative
- Additional dependency
- Migration effort to refactor existing code
- Team needs to learn Pydantic Settings pattern

---

## References

- [Pydantic Settings Docs](https://docs.pydantic.dev/latest/concepts/pydantic_settings/)
- [12-Factor App: Config](https://12factor.net/config)
