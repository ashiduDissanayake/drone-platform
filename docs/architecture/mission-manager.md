# Mission Manager Responsibilities

## Purpose
The mission manager turns a deployment selection into ordered, adapter-agnostic mission commands.

## Inputs
- Deployment file (e.g. `deployments/full_sitl__single_device.yaml`).
- Referenced profile file in `profiles/`.
- Mission scenario catalog entry in `missions/`.

## Behavior in V1
1. Resolve deployment -> profile -> mission scenario.
2. Translate mission actions into high-level vehicle contract commands.
3. Send commands to the vehicle adapter stub.
4. Log returned telemetry envelope summaries.

## Adapter interaction
In V1 bootstrap, mission manager uses an in-process adapter object.
Default examples use the `ardupilot_sitl` backend tag, but command generation remains adapter-agnostic.
Compose files already declare transport placeholders (`TRANSPORT_KIND`, endpoints) for future split-host channels.
