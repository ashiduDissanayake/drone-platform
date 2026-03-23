# Architecture Plan: Sprint 1 — ROS2 Foundation

## 1. Component Map

```
EC2 Ubuntu 22.04
│
├── ArduPilot SITL (existing)
│   └── MAVLink TCP on 0.0.0.0:5760
│
├── Gazebo Harmonic headless (existing)
│   └── ardupilot_gazebo plugin ←→ SITL on 127.0.0.1 (loopback, no packet loss)
│
├── MAVROS2 (NEW)
│   ├── Subscribes to MAVLink on tcp://127.0.0.1:5761
│   └── Publishes to ROS2 DDS topics:
│       ├── /mavros/global_position/global  (NavSatFix)
│       ├── /mavros/local_position/pose     (PoseStamped)
│       ├── /mavros/state                   (State — armed, mode)
│       ├── /mavros/battery                 (BatteryState)
│       ├── /mavros/imu/data                (Imu)
│       └── /mavros/global_position/rel_alt (Float64)
│
├── ros_gz_bridge (NEW)
│   └── Bridges Gazebo Transport → ROS2:
│       ├── /camera/image_raw               (sensor_msgs/Image)
│       └── /world/iris_runway/pose/info    (drone pose in Gazebo)
│
├── rosbridge_suite (NEW)
│   ├── WebSocket server on 0.0.0.0:9090
│   └── JSON-encodes ROS2 messages for browser consumption
│
└── Foxglove Bridge (NEW, dev/debug only)
    └── WebSocket server on 0.0.0.0:8765
        └── Connect Foxglove Studio at studio.foxglove.dev
```

**Browser (verification)**
```
Foxglove Studio (studio.foxglove.dev)
└── Connect to ws://15.207.113.11:8765
    ├── 3D Panel: drone position from /mavros/local_position/pose
    ├── Map Panel: GPS from /mavros/global_position/global
    ├── Image Panel: camera from /camera/image_raw
    └── Plot Panel: altitude from /mavros/global_position/rel_alt
```

## 2. ROS2 Package Selection

| Package | Version | Purpose |
|---|---|---|
| ros-humble-desktop | 2.x | Full ROS2 Humble install |
| ros-humble-mavros | 2.x | ArduPilot ↔ ROS2 bridge |
| ros-humble-mavros-extras | 2.x | Extra MAVROS plugins |
| ros-humble-rosbridge-suite | 1.x | WebSocket bridge for browser |
| ros-humble-ros-gz-bridge | 0.x | Gazebo ↔ ROS2 bridge |
| foxglove-bridge | latest | Foxglove Studio connection |

## 3. MAVROS2 Configuration

MAVROS2 connects to MAVLink source (ArduPilot SITL via MAVProxy):

```yaml
# ros2/config/mavros_params.yaml
mavros:
  ros__parameters:
    fcu_url: "tcp://127.0.0.1:5761"   # SITL serial0 TCP port
    gcs_url: ""
    target_system_id: 1
    target_component_id: 1
    system_id: 255
    plugin_allowlist:
      - sys_status
      - sys_time
      - imu
      - global_position
      - local_position
      - battery
      - command
      - setpoint_raw
```

## 4. rosbridge WebSocket Topics Available to Browser

Once rosbridge is running on port 9090, any browser using roslibjs can:

```javascript
// Subscribe to GPS position
var gps = new ROSLIB.Topic({
  ros: ros,
  name: '/mavros/global_position/global',
  messageType: 'sensor_msgs/NavSatFix'
});
gps.subscribe(function(msg) {
  console.log(msg.latitude, msg.longitude, msg.altitude);
});

// Subscribe to armed state
var state = new ROSLIB.Topic({
  ros: ros,
  name: '/mavros/state',
  messageType: 'mavros_msgs/State'
});
state.subscribe(function(msg) {
  console.log(msg.armed, msg.mode);
});

// Call arm service
var armService = new ROSLIB.Service({
  ros: ros,
  name: '/mavros/cmd/arming',
  serviceType: 'mavros_msgs/CommandBool'
});
armService.callService(new ROSLIB.ServiceRequest({ value: true }), function(result) {
  console.log('Armed:', result.success);
});
```

## 5. Gazebo Camera Bridge

The iris_with_gimbal model in Gazebo has a camera. ros_gz_bridge exposes it as ROS2:

```bash
ros2 run ros_gz_bridge parameter_bridge \
  /world/iris_runway/model/iris_with_gimbal/model/gimbal/link/pitch_link/sensor/camera/image@sensor_msgs/msg/Image@gz.msgs.Image
```

Topic becomes: `/world/iris_runway/.../camera/image` → bridge to ROS2 `/camera/image_raw`

## 6. Ansible Role Updates Required

The Ansible `simulator` role needs a new task file: `infra/ansible/roles/simulator/tasks/ros2.yml`

Steps:
1. Add ROS2 Humble APT repository
2. Install ros-humble-desktop, mavros, rosbridge-suite, ros-gz-bridge, foxglove-bridge
3. Install GeographicLib datasets (required by MAVROS)
4. Write MAVROS2 launch file to `~/ros2_ws/src/drone_platform_bringup/`
5. Write rosbridge launch file
6. Add systemd services or screen sessions for auto-start

## 7. Security Group Changes

New ports to open in EC2 security group (infra/terraform/main.tf):
- TCP 9090 from 0.0.0.0/0 — rosbridge WebSocket (browser access)
- TCP 8765 from 0.0.0.0/0 — Foxglove Bridge (dev only, restrict to your IP)

## 8. Verification Checklist (Definition of Done)

1. `ros2 topic list` on EC2 shows `/mavros/global_position/global`, `/mavros/state`, `/mavros/battery`
2. `ros2 topic echo /mavros/global_position/global` shows live GPS coordinates matching SITL home position
3. `ros2 topic echo /mavros/state` shows `armed: False`, `mode: STABILIZE` (SITL default)
4. Foxglove Studio in browser connects to `ws://15.207.113.11:8765` and renders drone position on Map panel
5. rosbridge running on port 9090; roslibjs test script in browser subscribes to `/mavros/state` and logs it to console
6. `/camera/image_raw` visible in Foxglove Image panel (Gazebo camera feed in browser)
