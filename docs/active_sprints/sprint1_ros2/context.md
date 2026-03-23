# Context: Sprint 1 — ROS2 Foundation

## What
Integrate ROS2 into the drone platform stack running on EC2. ArduPilot SITL + Gazebo headless already proven working on EC2 loopback. This sprint adds the ROS2 layer on top, making all drone state available as standard ROS2 topics, and bridging those topics to the browser via rosbridge_suite.

## Why
ROS2 is the backbone that makes this platform extensible:
- Standard message types (sensor_msgs, geometry_msgs) decouple the UI from MAVLink protocol details
- rosbridge_suite gives any browser client real-time access to all drone topics via WebSocket — no custom backend protocol needed for Phase 1
- ros_gz_bridge exposes Gazebo sensor data (camera, LiDAR) as ROS2 topics — same path to browser
- Foxglove Studio (free, browser-based) can verify the full stack with zero custom UI code

## Current State
- ArduPilot SITL: running on EC2 (15.207.113.11), `--model JSON`, MAVProxy on port 5760
- Gazebo headless: running on EC2 loopback (gz sim -s), physics loop confirmed working
- vehicle_adapter: connects via `tcp:10.8.0.1:5760`, full MAVLink command set working
- ROS2: NOT installed on EC2 yet
- rosbridge: NOT installed
- Browser visualization: NOT implemented

## Who Cares
- Sprint 1 → Sprint 2 (API layer subscribes to MQTT which vehicle_adapter publishes to)
- Sprint 1 → Sprint 3 (React UI uses roslibjs to subscribe to rosbridge WebSocket)
- Long-term: all autonomy logic can publish/subscribe via ROS2 topics

## Constraints
- EC2 instance: Ubuntu 22.04, ap-south-1 Mumbai, t3.medium or larger
- ROS2 version: **Humble** (Ubuntu 22.04 LTS pair, supported until May 2027)
- MAVROS2 works with standard ArduPilot SITL binaries — no recompilation needed
- rosbridge_suite is ROS2 Humble compatible
- Port 9090 (rosbridge WebSocket) must be open in EC2 security group
