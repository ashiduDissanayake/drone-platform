# ✅ Cloud SITL is Ready!

## Connection Details

| Parameter | Value |
|-----------|-------|
| **EC2 IP** | 3.83.48.196 |
| **MAVLink** | tcp:3.83.48.196:5760 |
| **SSH** | ssh -i infra/terraform/sitl-key.pem ubuntu@3.83.48.196 |

## Quick Test

```bash
# Test connection
python3 -c "
from pymavlink import mavutil
master = mavutil.mavlink_connection('tcp:3.83.48.196:5760')
master.wait_heartbeat()
print('Connected!')
master.close()
"

# Using vehicle adapter
python3 -m adapters.vehicle_adapter \
  --connection tcp:3.83.48.196:5760 \
  --command arm \
  --wait-ready

# Using MAVProxy
mavproxy.py --master=tcp:3.83.48.196:5760

# Using mission manager
python3 -m autonomy.mission_manager \
  --deployment config/generated/cloud-deployment.yaml
```

## Management

```bash
# Check SITL status on EC2
ssh -i infra/terraform/sitl-key.pem ubuntu@3.83.48.196 "ps aux | grep arducopter"

# View SITL logs
ssh -i infra/terraform/sitl-key.pem ubuntu@3.83.48.196 "tail -f /tmp/sitl.log"

# Restart SITL
ssh -i infra/terraform/sitl-key.pem ubuntu@3.83.48.196 "pkill arducopter; sleep 2; cd ~/ardupilot/ArduCopter && ../build/sitl/bin/arducopter -w --model + --home -35.363261,149.165230,584,353 --defaults ../Tools/autotest/default_params/copter.parm --serial0 tcp:0.0.0.0:5760 > /tmp/sitl.log 2>&1 &"

# Destroy infrastructure (stop charges)
./cleanup-failed.sh
```

## Cost Warning

⚠️ **AWS charges ~$0.04/hour while EC2 is running (~$1/day)**

Always run `./cleanup-failed.sh` when done to stop charges.

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Can't connect | Run `./update-sg-ip.sh` (your IP may have changed) |
| SSH timeout | Check `./get-connection.sh` for diagnostics |
| SITL not responding | SSH in and check `tail -f /tmp/sitl.log` |

---
Generated: $(date)
