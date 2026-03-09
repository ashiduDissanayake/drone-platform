# Config Model Guide

The configuration system is composed of four filesets:

1. `profiles/`: simulated vs real component split.
2. `topologies/`: role-to-device placement (not host-specific).
3. `inventory/`: available concrete devices.
4. `deployments/`: selected composition and role assignment.

## Example relationship
- profile: `full_sitl`
- topology: `split_device`
- inventory: `devices.example.yaml`
- deployment: `full_sitl__split_device.yaml`

A deployment should be valid if:
- referenced profile exists,
- referenced topology exists,
- role assignments map to inventory device IDs,
- mission scenario matches profile constraints.
