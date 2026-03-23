# Tasks: Sprint 3 — React UI Foundation

**Sprint goal:** React application with CesiumJS mission planner and Babylon.js simulation view. Live telemetry from MQTT updates both views. Commands work from command bar. Verified: arm → takeoff → fly waypoint → land all triggered from browser UI.

---

## Task 1 — Scaffold React + Vite + TypeScript

- [ ] Create `ui/` directory
- [ ] `npm create vite@latest ui -- --template react-ts`
- [ ] Install dependencies: `npm install mqtt cesium babylonjs @babylonjs/loaders zustand @tanstack/react-query react-router-dom tailwindcss`
- [ ] Install CesiumJS Vite plugin: `npm install vite-plugin-cesium`
- [ ] Configure `vite.config.ts` with cesium plugin
- [ ] Configure Tailwind CSS
- [ ] **Verify:** `npm run dev` starts, browser shows default React page at localhost:5173

## Task 2 — MQTT connection + Zustand store

- [ ] Implement `src/services/mqtt.ts`: MQTT.js client connecting to `ws://15.207.113.11:8083/mqtt`
- [ ] Implement `src/store/drone.ts`: Zustand store with `telemetry` field (lat, lon, alt_m, armed, mode, battery_pct)
- [ ] Implement `src/hooks/useTelemetry.ts`: subscribe to `drones/v1/telemetry`, parse JSON, update store
- [ ] **Verify:** `console.log` in useTelemetry shows telemetry arriving at 10Hz from EC2 SITL

## Task 3 — TelemetryPanel + CommandBar components

- [ ] Build `src/components/TelemetryPanel.tsx`: shows lat/lon/alt/mode/armed/battery updating live
- [ ] Build `src/components/CommandBar.tsx`: buttons for Arm, Takeoff (10m), Land, RTL
- [ ] Implement `src/hooks/useCommand.ts`: TanStack mutation calling `POST http://15.207.113.11:8000/command`
- [ ] Wire CommandBar buttons to useCommand hook
- [ ] **Verify:** Arm button sends POST /command → SITL arms (verify via `ros2 topic echo /mavros/state`)

## Task 4 — CesiumJS Mission Planner view

- [ ] Create `src/views/MissionPlanner.tsx` with CesiumJS Viewer filling the view
- [ ] Set CesiumJS home position to SITL home (-35.363261, 149.165230)
- [ ] Add live drone entity: position from Zustand telemetry state, updated at 10Hz
- [ ] Add click handler: clicking globe adds waypoint billboard entity
- [ ] Add waypoint list panel (sidebar): shows waypoint coordinates, allow delete
- [ ] Add "Run Mission" button: generates mission YAML from waypoint list, POST to `/mission/run`
- [ ] **Verify:** Click 3 points on globe → click Run Mission → SITL drone flies to waypoints

## Task 5 — Babylon.js Simulation View

- [ ] Create `src/views/SimulationView.tsx` with Babylon.js Engine + Scene
- [ ] Import iris drone glTF model (source from ardupilot_gazebo models or Sketchfab free model)
- [ ] Update drone mesh position at 10Hz from Zustand telemetry (GPS → ENU conversion)
- [ ] Update drone mesh rotation from telemetry (mode: use heading from MAVLink)
- [ ] Add basic environment (ground plane, sky dome)
- [ ] **Verify:** Drone mesh moves in 3D when SITL flies (arm → takeoff → visible altitude change)

## Task 6 — Layout: routing + nav

- [ ] Implement `src/App.tsx` with React Router: `/plan` → MissionPlanner, `/sim` → SimulationView
- [ ] Build navigation bar: toggle between views, show armed state + battery persistently
- [ ] TelemetryPanel and CommandBar always visible (both views)
- [ ] **Verify:** Nav between views works; telemetry + command bar persist across route changes

## Task 7 — Build + serve from FastAPI

- [ ] Run `npm run build` → produces `ui/dist/`
- [ ] In `api/main.py`, mount `ui/dist` as static files at root path
- [ ] **Verify:** `http://15.207.113.11:8000` serves the React app from EC2

---

## Done Criteria

All boxes checked **AND**:
- Screen recording showing: browser opens → telemetry panel shows live altitude → click Arm → drone arms (panel updates) → click Takeoff → drone climbs in Babylon.js view → CesiumJS view shows drone moving on globe → click Land → drone lands
