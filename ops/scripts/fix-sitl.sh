#!/bin/bash
# Fix script for SITL setup issues on existing EC2 instance

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TF_DIR="${REPO_ROOT}/infra/terraform"

echo "=========================================="
echo "  Fixing SITL on Existing EC2 Instance"
echo "=========================================="

# Get EC2 IP
if [ ! -f "${TF_DIR}/terraform.tfstate" ]; then
    echo "❌ Terraform state not found. Run ./quickstart.sh first."
    exit 1
fi

cd "${TF_DIR}"
EC2_IP=$(terraform output -raw sitl_public_ip 2>/dev/null || echo "")

if [ -z "$EC2_IP" ]; then
    echo "❌ Could not get EC2 IP from Terraform"
    exit 1
fi

echo "EC2 IP: ${EC2_IP}"

# Check SSH connectivity
echo ""
echo "Checking SSH connectivity..."
if ! ssh -i sitl-key.pem -o StrictHostKeyChecking=no -o ConnectTimeout=10 ubuntu@${EC2_IP} "echo 'SSH OK'" 2>/dev/null; then
    echo "❌ Cannot connect to EC2 via SSH"
    echo "   Check security group and that instance is running"
    exit 1
fi
echo "✓ SSH connection OK"

# Fix Python symlink and install dependencies
echo ""
echo "Fixing Python setup..."
ssh -i sitl-key.pem -o StrictHostKeyChecking=no ubuntu@${EC2_IP} << 'SSH_EOF'
    # Create python symlink
    sudo update-alternatives --install /usr/bin/python python /usr/bin/python3 1
    
    # Install additional Python packages
    sudo pip3 install -U pymavlink pyserial pexpect future lxml empy
    
    # Check ArduPilot clone
    if [ ! -d "~/ardupilot/.git" ]; then
        echo "ArduPilot not properly cloned, removing and re-cloning..."
        rm -rf ~/ardupilot
        git clone --depth 1 --recursive --branch Copter-4.4 https://github.com/ArduPilot/ardupilot.git ~/ardupilot
    fi
    
    cd ~/ardupilot
    
    # Configure and build
    echo "Configuring waf..."
    ./waf configure --board sitl 2>&1 || true
    
    echo "Building ArduCopter (this takes 10-20 minutes)..."
    ./waf copter 2>&1 || true
    
    # Check if binary was created
    if [ -f "build/sitl/bin/arducopter" ]; then
        echo "✓ SITL binary built successfully"
        
        # Create start script
        cat > ~/start-sitl.sh << 'START_SCRIPT'
#!/bin/bash
cd ~/ardupilot/ArduCopter
pkill -f arducopter 2>/dev/null || true
sleep 2
echo "Starting SITL on tcp:0.0.0.0:5760..."
../build/sitl/bin/arducopter -w --model + --home -35.363261,149.165230,584,353 --defaults ../Tools/autotest/default_params/copter.parm --serial0 tcp:0.0.0.0:5760
START_SCRIPT
        chmod +x ~/start-sitl.sh
        
        # Setup systemd service
        sudo tee /etc/systemd/system/ardupilot-sitl.service > /dev/null << 'SYSTEMD'
[Unit]
Description=ArduPilot SITL Simulator
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu/ardupilot/ArduCopter
ExecStart=/home/ubuntu/ardupilot/build/sitl/bin/arducopter -w --model + --home -35.363261,149.165230,584,353 --defaults ../Tools/autotest/default_params/copter.parm --serial0 tcp:0.0.0.0:5760
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
SYSTEMD
        
        sudo systemctl daemon-reload
        sudo systemctl enable ardupilot-sitl
        sudo systemctl restart ardupilot-sitl
        
        echo "✓ SITL service started"
    else
        echo "❌ SITL binary not found after build"
        echo "   Check build errors above"
        exit 1
    fi
SSH_EOF

echo ""
echo "=========================================="
echo "  SITL Fix Applied!"
echo "=========================================="
echo ""
echo "Connection: tcp://${EC2_IP}:5760"
echo ""
echo "Test with:"
echo "  python3 -m autonomy.mission_manager --deployment config/generated/cloud-deployment.yaml"
echo ""
