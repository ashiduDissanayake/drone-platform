# Tasks: Sprint 1 — ROS2 Foundation

**Sprint goal:** ArduPilot SITL + Gazebo headless on EC2 with all drone state as ROS2 topics. Browser can subscribe to live telemetry via rosbridge WebSocket. Verified in Foxglove Studio.

---

## Task 1 — EC2: Install ROS2 Humble

- [ ] SSH to EC2, add ROS2 Humble APT repository (key + source)
  ```bash
  sudo apt-get install -y software-properties-common curl
  sudo curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key \
    -o /usr/share/keyrings/ros-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] \
    http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo $UBUNTU_CODENAME) main" \
    | sudo tee /etc/apt/sources.list.d/ros2.list > /dev/null
  sudo apt-get update
  ```
- [ ] Install ROS2 Humble base + tools
  ```bash
  sudo apt-get install -y ros-humble-ros-base python3-colcon-common-extensions python3-rosdep
  ```
- [ ] Source ROS2 in `.bashrc`
  ```bash
  echo "source /opt/ros/humble/setup.bash" >> ~/.bashrc
  source ~/.bashrc
  ```
- [ ] **Verify:** `ros2 --version` returns `ros2 cli 0.18.x`

## Task 2 — EC2: Install MAVROS2

- [ ] Install MAVROS2 and extras packages
  ```bash
  sudo apt-get install -y ros-humble-mavros ros-humble-mavros-extras
  ```
- [ ] Install GeographicLib datasets (mandatory for MAVROS)
  ```bash
  sudo /opt/ros/humble/lib/mavros/install_geographiclib_datasets.sh
  ```
- [ ] **Verify:** `ros2 pkg list | grep mavros` returns `mavros` and `mavros_msgs`

## Task 3 — EC2: Launch MAVROS2 and verify topics

- [ ] Start MAVROS2 in a screen session, connecting to SITL MAVProxy on port 5761
  ```bash
  screen -S mavros
  source /opt/ros/humble/setup.bash
  ros2 launch mavros apm.launch fcu_url:=tcp://127.0.0.1:5761 gcs_url:=''
  ```
- [ ] In another terminal, check topics
  ```bash
  source /opt/ros/humble/setup.bash
  ros2 topic list
  ```
- [ ] **Verify:** Topic list includes:
  - `/mavros/global_position/global`
  - `/mavros/local_position/pose`
  - `/mavros/state`
  - `/mavros/battery`
  - `/mavros/imu/data`
- [ ] **Verify:** `ros2 topic echo /mavros/state` shows `connected: True`
- [ ] **Verify:** `ros2 topic echo /mavros/global_position/global` shows non-zero latitude

## Task 4 — EC2: Install and launch rosbridge_suite

- [ ] Install rosbridge_suite
  ```bash
  sudo apt-get install -y ros-humble-rosbridge-suite
  ```
- [ ] Launch rosbridge WebSocket server on port 9090 in screen
  ```bash
  screen -S rosbridge
  source /opt/ros/humble/setup.bash
  ros2 launch rosbridge_server rosbridge_websocket_launch.xml port:=9090
  ```
- [ ] Open port 9090 in EC2 security group (add to infra/terraform/main.tf or via AWS console)
- [ ] **Verify:** `ss -tlnp | grep 9090` shows rosbridge listening
- [ ] **Verify:** From Mac terminal: `wscat -c ws://15.207.113.11:9090` connects without error (install wscat: `npm install -g wscat`)

## Task 5 — EC2: Install and launch Foxglove Bridge

- [ ] Install Foxglove Bridge
  ```bash
  sudo apt-get install -y ros-humble-foxglove-bridge
  ```
- [ ] Launch Foxglove Bridge in screen
  ```bash
  screen -S foxglove
  source /opt/ros/humble/setup.bash
  ros2 launch foxglove_bridge foxglove_bridge_launch.xml port:=8765
  ```
- [ ] Open port 8765 in EC2 security group (restrict to your IP for security)
- [ ] **Verify:** Open `https://studio.foxglove.dev` in browser → Open Connection → `ws://15.207.113.11:8765` → connects

## Task 6 — Browser: Verify Foxglove Studio

- [ ] In Foxglove Studio, add a **Map Panel**: set topic to `/mavros/global_position/global` → drone appears at SITL home position (-35.363261, 149.165230)
- [ ] Add a **3D Panel**: add `/mavros/local_position/pose` → see drone frame
- [ ] Add a **Plot Panel**: plot `/mavros/global_position/rel_alt.data` → shows 0.0m at rest
- [ ] Add a **State Panel** or Raw Messages panel: `/mavros/state` shows `armed: False`, mode visible
- [ ] **Verify done criteria:** All panels show live updating data from real SITL

## Task 7 — EC2: ros_gz_bridge for camera

- [ ] Install ros_gz_bridge
  ```bash
  sudo apt-get install -y ros-humble-ros-gz-bridge
  ```
- [ ] Find the exact Gazebo camera topic name
  ```bash
  gz topic -l | grep camera
  ```
- [ ] Launch bridge for camera image
  ```bash
  screen -S gz_bridge
  source /opt/ros/humble/setup.bash
  ros2 run ros_gz_bridge parameter_bridge \
    <gz-camera-topic>@sensor_msgs/msg/Image@gz.msgs.Image
  ```
- [ ] **Verify:** `ros2 topic list | grep image` shows the camera topic
- [ ] **Verify:** In Foxglove Studio, add Image Panel → camera feed from Gazebo visible in browser

## Task 8 — Ansible: Codify ROS2 setup

- [ ] Create `infra/ansible/roles/simulator/tasks/ros2.yml` with all installation steps from Tasks 1–7
- [ ] Add `ros2.yml` to `infra/ansible/roles/simulator/tasks/main.yml` include list
- [ ] Test: provision a fresh EC2 and verify all done criteria pass automatically
- [ ] **Verify:** `ansible-playbook infra/ansible/site.yml` produces a fully functional ROS2 stack

---

## Done Criteria

All boxes checked **AND**:
- Screenshot of Foxglove Studio showing drone position on Map panel with live GPS from SITL
- Screenshot of Foxglove Studio Image panel showing Gazebo camera feed
- `ros2 topic echo /mavros/state` log snippet showing `connected: True, armed: False`
