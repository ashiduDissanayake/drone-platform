# ADR 0005: Prefer ArduPilot as V1 Autopilot Backend

- Status: Accepted
- Date: 2026-03-11

## Context
V1 needs one clear autopilot default for onboarding, config examples, and stub execution paths.
The repository already isolates autopilot-specific behavior behind the vehicle adapter contract and keeps mission logic adapter-agnostic.

## Decision
Prefer ArduPilot as the default autopilot backend for V1:
- `full_sitl` profile defaults vehicle backend to `ardupilot_sitl`.
- `companion_hybrid` profile defaults vehicle backend to `ardupilot`.
- Vehicle adapter and mission manager CLI defaults use `ardupilot_sitl`.
- Compose placeholders and docs describe ArduPilot SITL as the primary V1 backend path.

## What Changes
- Default backend names and placeholder service naming are ArduPilot-oriented.
- Onboarding and architecture docs identify ArduPilot SITL as the primary V1 autopilot path.
- Existing mission scenario remains `takeoff -> waypoint -> land`.

## What Does Not Change
- The profile/topology/inventory/deployment model.
- Multi-device-first requirement and no-localhost-only constraint.
- Mission manager architecture and adapter boundary.
- Simulator abstraction (Gazebo remains the current world simulator placeholder).
- V1 scope boundaries (no cloud/swarm/perception expansion).

## Consequences
- Pros: clearer V1 default path, consistent naming across configs/docs, lower onboarding ambiguity.
- Cons: no real ArduPilot flight integration is delivered yet in V1 bootstrap; adapter behavior remains stubbed.

## Future Flexibility
Backend flexibility is preserved because autonomy emits contract-level commands only.
Adding or switching autopilot backends remains an adapter/config change, not a mission-manager redesign.
