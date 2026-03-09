# Architecture Overview (V1 Bootstrap)

The platform is modeled through four independent but composable layers:

1. **Profile**: defines simulated vs real components.
2. **Topology**: maps runtime roles to device roles.
3. **Inventory**: defines concrete physical devices and capabilities.
4. **Deployment**: selects and binds profile + topology + inventory.

V1 validates:
- Profile A: Full SITL
- Profile C: Companion Hybrid
- Topology T1: Single Device
- Topology T2: Split Device
- Mission path: takeoff -> waypoint -> land

Non-goals in bootstrap:
- Deep autonomy/perception implementation
- Cloud/swarm architecture
- Simulator-specific logic in mission manager
