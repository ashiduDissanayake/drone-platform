# Tasks: Sprint 2 — API + MQTT Layer

**Sprint goal:** FastAPI command API + EMQX MQTT broker running on EC2. Browser can subscribe to live 10Hz drone telemetry via MQTT.js. Commands (arm, takeoff, land) work via HTTP POST. Verified with a minimal HTML test page.

---

## Task 1 — EC2: Deploy EMQX broker

- [ ] Create `infra/compose/emqx.yml` with EMQX 5.x service definition
- [ ] On EC2, start EMQX: `docker compose -f infra/compose/emqx.yml up -d`
- [ ] Open ports in EC2 security group: TCP 8083 (MQTT/WS), TCP 18083 (dashboard, your IP only)
- [ ] **Verify:** `curl http://15.207.113.11:18083` returns EMQX dashboard HTML
- [ ] **Verify:** MQTT.js test from Mac: `npm install -g mqtt && mqtt subscribe -h 15.207.113.11 -p 8083 -l ws -t 'test/#'` connects without error

## Task 2 — Build api/: FastAPI skeleton

- [ ] Create `api/` directory with `__init__.py`, `main.py`, `requirements.txt`
- [ ] Install: `fastapi`, `uvicorn`, `aiomqtt` (or `paho-mqtt`), `pymavlink`
- [ ] Implement GET `/health` endpoint returning stack status
- [ ] Implement POST `/command` endpoint calling `vehicle_adapter.execute()`
- [ ] Add CORS middleware (allow all origins for development)
- [ ] **Verify:** `uvicorn api.main:app` starts without error; `curl localhost:8000/health` returns JSON

## Task 3 — api/: Background telemetry publisher

- [ ] Implement `api/services/telemetry.py` with async loop: get MAVLink telemetry → publish to EMQX `drones/v1/telemetry` at 10Hz
- [ ] Start telemetry loop in FastAPI lifespan context manager
- [ ] **Verify:** With EMQX running and SITL connected, `mqtt subscribe -h 15.207.113.11 -p 8083 -l ws -t 'drones/v1/telemetry'` shows JSON messages arriving every ~100ms

## Task 4 — api/: Mission run endpoint

- [ ] Implement `POST /mission/run` that accepts mission YAML, stores it, runs `mission_manager` in background task
- [ ] Implement `GET /mission/{id}/status` that returns current step and completion state
- [ ] Publish mission status updates to `drones/v1/mission/status` MQTT topic (QoS 1)
- [ ] **Verify:** POST a mission YAML → get back mission_id → GET status shows progress → completes

## Task 5 — Browser test page

- [ ] Create `api/static/test.html` — minimal HTML page that:
  - Connects to MQTT over WebSocket on port 8083
  - Subscribes to `drones/v1/telemetry`
  - Renders lat/lon/alt/armed/mode updating live
  - Has buttons for arm, takeoff (10m), land that call POST /command
- [ ] **Verify:** Open `http://15.207.113.11:8000/static/test.html` in browser → telemetry updates live → arm button successfully arms SITL

## Task 6 — EC2 security group + Terraform

- [ ] Add TCP 8083 (MQTT WebSocket) to `infra/terraform/main.tf` security group rules
- [ ] Add TCP 8000 (FastAPI) to security group rules
- [ ] `terraform apply` to update rules
- [ ] **Verify:** Browser on Mac can reach both ports from public internet

## Task 7 — Ansible: Codify API + EMQX setup

- [ ] Add EMQX Docker Compose start to Ansible role
- [ ] Add FastAPI install + start (systemd service or screen session) to Ansible role
- [ ] **Verify:** Fresh EC2 provision via Ansible brings up full stack automatically

---

## Done Criteria

All boxes checked **AND**:
- Screen recording or GIF of test.html showing live telemetry updating from SITL
- `curl -X POST http://15.207.113.11:8000/command -d '{"vehicle_id":"v1","command":"arm","params":{}}'` returns success
- MQTT subscriber on Mac receives telemetry at ~10Hz
