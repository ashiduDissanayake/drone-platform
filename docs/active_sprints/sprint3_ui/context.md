# Context: Sprint 3 — React UI Foundation

## What
Build the web UI: React application with two primary views — a CesiumJS GPS-accurate mission planner, and a Babylon.js 3D simulation view. Connects to EMQX MQTT for live telemetry and FastAPI for commands.

## Why
- **React**: Component model maps naturally to the multi-panel GCS layout. Large ecosystem (react-query for API state, zustand for global state, react-router for views). TypeScript adds safety across the API contract.
- **CesiumJS for mission planning**: True WGS84 GPS accuracy. Draw waypoints by clicking on a real-world 3D globe. Upload missions directly to the backend. See flight paths and history. No other browser 3D library handles global GPS coordinates correctly.
- **Babylon.js for simulation view**: Game engine quality rendering. Shows the drone in its Gazebo simulated world (local ENU coordinates). Camera feed as VideoTexture in the same scene. High-fidelity for inspection missions.
- **MQTT.js**: Direct broker subscription from browser. No backend fan-out needed. 10Hz telemetry with QoS 0.

## Current State (after Sprint 2)
- EMQX: running on EC2, `drones/v1/telemetry` topic publishing at 10Hz
- FastAPI: running on EC2, POST /command and GET /health working
- Browser test page: raw HTML verified MQTT connection and commands work
- React UI: nothing built yet

## Two Views

**View 1 — Mission Planner (CesiumJS)**
Purpose: GPS-accurate mission planning. Click on the globe to place waypoints. Define takeoff altitude. Preview the mission path in 3D. Upload to vehicle and execute. Monitor live drone position on globe.

**View 2 — Simulation View (Babylon.js)**
Purpose: Close-range 3D drone visualization in the Gazebo simulated world. Shows the drone model with accurate orientation (roll/pitch/yaw). Camera feed from the drone's gimbal camera overlaid in the corner. Best for monitoring autonomous inspection flight.
