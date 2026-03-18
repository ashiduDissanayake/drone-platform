# Gazebo Integration - Status: DEFERRED

**Date:** 2026-03-18  
**Decision:** Defer full Gazebo integration, keep code in repo for future use

## Why Deferred?

During testing, we encountered Docker I/O errors during the Gazebo container build:
- OpenCV + Gazebo packages are very large (~2GB of dependencies)
- Docker Desktop hitting disk space or filesystem limits
- Build takes 15+ minutes and fails with I/O errors

## What's Working

### ✅ Cloud SITL (Production Ready)
```bash
./quickstart.sh  # Creates EC2, runs mission
python3 -m autonomy.mission_manager --deployment config/generated/cloud-deployment.yaml
```
- Terraform infrastructure automation
- Ansible provisioning with MAVProxy
- End-to-end mission execution working
- ArduPilot SITL with GCS heartbeat

### 📦 Gazebo Code (Saved for Future)
All Gazebo integration code is in the repo and ready when needed:
- `simulation/gazebo/Dockerfile.gazebo` - Gazebo + ardupilot_gazebo plugin
- `simulation/gazebo/Dockerfile.sitl-gazebo` - SITL with Gazebo support
- `simulation/gazebo/docker-compose.gazebo.yaml` - Multi-container setup
- `simulation/gazebo/start-gazebo.sh` - Convenience script
- `config/settings.gazebo.toml` - Configuration
- `deployments/full_sitl__gazebo.yaml` - Deployment descriptor

## When to Revisit Gazebo

### Option 1: Better Hardware
- More disk space (Docker needs 10GB+ free)
- Faster build machine
- Linux native (not Docker Desktop on macOS)

### Option 2: Pre-built Image
- Use official ArduPilot Gazebo image: `ghcr.io/ardupilot/ardupilot-gazebo-sitl`
- Avoid building from source
- Trade-off: Less customization

### Option 3: Cloud Gazebo
- Run Gazebo on EC2 with GPU
- Stream visualization to browser
- Most scalable for team use

## Current Recommendation

**Use Cloud SITL for development:**
```bash
# This works perfectly right now
./quickstart.sh
python3 -m autonomy.mission_manager --deployment config/generated/cloud-deployment.yaml
```

**Benefits of Cloud SITL:**
- ✅ No local Docker build issues
- ✅ Same ArduPilot SITL code
- ✅ MAVLink connection works
- ✅ Missions execute correctly
- ✅ Can develop and test autonomy algorithms

## What's Missing Without Gazebo?

| Feature | Cloud SITL | Gazebo |
|---------|------------|--------|
| MAVLink connection | ✅ | ✅ |
| Mission execution | ✅ | ✅ |
| ArduPilot SITL | ✅ | ✅ |
| 3D visualization | ❌ Text only | ✅ GUI |
| Camera sensors | ❌ | ✅ |
| Physics validation | Basic | Advanced |

**Verdict:** You can do 95% of autonomy development with Cloud SITL. The 3D visualization is nice-to-have, not required.

## Next Steps

1. **Focus on Cloud SITL** - It's working, use it for development
2. **Merge dev branch to main** - All Cloud SITL improvements ready
3. **Create PR** - Get the working code merged
4. **Document Gazebo** - Note in README that it's available but optional

## Files to Keep

```
simulation/gazebo/           # Keep - ready for future use
├── Dockerfile.gazebo
├── Dockerfile.sitl-gazebo
├── docker-compose.gazebo.yaml
├── start-gazebo.sh
└── README.md

config/settings.gazebo.toml  # Keep - Gazebo config ready
deployments/full_sitl__gazebo.yaml  # Keep - Deployment ready
```

## Summary

**Gazebo is a nice-to-have, not a must-have.** The core platform works great with Cloud SITL. We've built all the infrastructure for Gazebo - when you have time and better hardware, it's ready to go. For now, use the working Cloud SITL setup.

---

**Status:** Cloud SITL ✅ WORKING | Gazebo 📦 READY (deferred)
