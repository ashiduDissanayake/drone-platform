# Architecture Plan: Sprint 3 — React UI Foundation

## 1. Tech Stack

| Layer | Choice | Reason |
|---|---|---|
| Framework | React 18 + TypeScript | Component model, ecosystem, type safety |
| Build tool | Vite | Fast HMR, TypeScript native, small bundles |
| Routing | React Router v6 | View routing (mission planner / simulation view) |
| State | Zustand | Minimal boilerplate, good for telemetry state |
| API calls | TanStack Query | Mutation state for commands, cache for mission status |
| MQTT | MQTT.js | Browser MQTT over WebSocket, subscribe to telemetry |
| 3D Map | CesiumJS | GPS-accurate globe, mission waypoint planning |
| 3D Sim | Babylon.js | Game engine quality, camera feed, local ENU frame |
| Styling | Tailwind CSS | Utility-first, fast to build GCS panels |

## 2. File Structure

```
ui/
├── index.html
├── package.json
├── vite.config.ts
├── tsconfig.json
├── src/
│   ├── main.tsx               ← React root
│   ├── App.tsx                ← Router, layout
│   ├── views/
│   │   ├── MissionPlanner.tsx ← CesiumJS view
│   │   └── SimulationView.tsx ← Babylon.js view
│   ├── components/
│   │   ├── TelemetryPanel.tsx ← lat/lon/alt/mode/battery
│   │   ├── CommandBar.tsx     ← arm/takeoff/land/RTL buttons
│   │   └── MissionStatus.tsx  ← step progress bar
│   ├── hooks/
│   │   ├── useTelemetry.ts    ← MQTT subscription, zustand update
│   │   └── useCommand.ts      ← TanStack mutation → POST /command
│   ├── services/
│   │   ├── mqtt.ts            ← MQTT.js client singleton
│   │   └── api.ts             ← FastAPI fetch wrapper
│   └── store/
│       └── drone.ts           ← Zustand: telemetry, mission state
```

## 3. Telemetry Data Flow

```
EMQX (EC2 :8083)
  → MQTT.js (browser, ws://)
  → useTelemetry hook (parses JSON)
  → Zustand store (droneState.telemetry)
  → TelemetryPanel (alt, mode, battery)
  → CesiumJS Entity position update (lat/lon/alt)
  → Babylon.js mesh position update (ENU x/y/z)
```

## 4. CesiumJS Mission Planner

- Click on globe to add waypoints (lat/lon from CesiumJS mouse pick)
- Waypoints shown as billboard entities with altitude labels
- Connect waypoints with a `PolylineGraphics` entity
- "Execute Mission" button → POST /mission/run with YAML generated from waypoints
- Live drone entity follows `drones/v1/telemetry` position at 10Hz
- `SampledPositionProperty` for smooth interpolation between 10Hz updates
- `trackedEntity` option to lock camera on drone during flight

## 5. Babylon.js Simulation View

- Scene uses local ENU coordinate system (origin = SITL home position)
- Drone mesh: glTF model loaded from `/public/models/iris.glb`
- Position update: ENU converted from MAVLink LOCAL_POSITION_NED (x=north, y=east, z=-alt)
- Orientation: quaternion from `/mavros/local_position/pose` → Babylon.js rotation quaternion
- Rotor animations: spin speed proportional to throttle (from MAVROS actuator state)
- Camera feed: VideoTexture on a plane primitive in bottom-right of scene

## 6. ENU Coordinate Conversion (for Babylon.js)

GPS coordinates from CesiumJS or MAVROS must be converted to local ENU for Babylon.js:

```typescript
// Given home origin (lat0, lon0, alt0) and current (lat, lon, alt)
// Returns ENU (east, north, up) in meters
function gpsToENU(lat0: number, lon0: number, lat: number, lon: number, alt: number) {
  const R = 6371000; // Earth radius in meters
  const dLat = (lat - lat0) * Math.PI / 180;
  const dLon = (lon - lon0) * Math.PI / 180;
  const north = dLat * R;
  const east = dLon * R * Math.cos(lat0 * Math.PI / 180);
  return { x: east, y: alt, z: -north }; // Babylon.js Y-up
}
```

## 7. Deployment

UI is built as static files (`vite build`) and served by FastAPI as a static mount:
```python
app.mount("/", StaticFiles(directory="ui/dist", html=True), name="ui")
```
No separate web server needed. Single EC2 port 8000 serves both the API and the UI.
