#!/bin/bash
# Development Environment Setup Script
# One command to set up everything needed for drone-platform development
# Usage: ./setup-dev-env.sh [--force]

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FORCE=false

# Parse args
if [ "$1" == "--force" ]; then
    FORCE=true
fi

echo "=========================================="
echo "  Drone Platform - Dev Environment Setup"
echo "=========================================="
echo ""
echo "Platform: $(uname -s)"
echo "Arch: $(uname -m)"
echo ""

# Detect OS
OS="unknown"
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
    PACKAGE_MANAGER="brew"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
    if command -v apt-get &> /dev/null; then
        PACKAGE_MANAGER="apt"
    elif command -v yum &> /dev/null; then
        PACKAGE_MANAGER="yum"
    else
        PACKAGE_MANAGER="unknown"
    fi
else
    echo -e "${RED}Unsupported OS: $OSTYPE${NC}"
    echo "Supported: macOS, Linux (Ubuntu/Debian, CentOS/RHEL)"
    exit 1
fi

echo -e "${BLUE}Detected OS: $OS${NC}"
echo -e "${BLUE}Package Manager: $PACKAGE_MANAGER${NC}"
echo ""

# Function to check if command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Function to install with Homebrew
install_brew() {
    local package=$1
    local command_name=${2:-$package}
    
    if command_exists "$command_name" && [ "$FORCE" = false ]; then
        echo -e "${GREEN}✓ $package already installed${NC}"
        return 0
    fi
    
    echo -e "${YELLOW}Installing $package...${NC}"
    brew install "$package"
    echo -e "${GREEN}✓ $package installed${NC}"
}

# Function to install with apt
install_apt() {
    local package=$1
    local command_name=${2:-$package}
    
    if command_exists "$command_name" && [ "$FORCE" = false ]; then
        echo -e "${GREEN}✓ $package already installed${NC}"
        return 0
    fi
    
    echo -e "${YELLOW}Installing $package...${NC}"
    sudo apt-get update -qq
    sudo apt-get install -y -qq "$package"
    echo -e "${GREEN}✓ $package installed${NC}"
}

# ============================================
# 1. Check/Install Package Manager
# ============================================
echo "[1/7] Checking package manager..."

if [ "$OS" == "macos" ]; then
    if ! command_exists brew; then
        echo -e "${YELLOW}Homebrew not found. Installing...${NC}"
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        echo -e "${GREEN}✓ Homebrew installed${NC}"
    else
        echo -e "${GREEN}✓ Homebrew already installed${NC}"
    fi
elif [ "$OS" == "linux" ]; then
    echo -e "${GREEN}✓ Using system package manager${NC}"
fi

# ============================================
# 2. Install Python 3.10+
# ============================================
echo ""
echo "[2/7] Checking Python..."

if command_exists python3; then
    PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
    echo -e "${GREEN}✓ Python $PYTHON_VERSION installed${NC}"
    
    # Check version >= 3.10
    if python3 -c "import sys; exit(0 if sys.version_info >= (3, 10) else 1)"; then
        echo -e "${GREEN}✓ Python version OK (>= 3.10)${NC}"
    else
        echo -e "${YELLOW}Python version < 3.10, upgrading...${NC}"
        if [ "$OS" == "macos" ]; then
            install_brew "python@3.11"
        elif [ "$OS" == "linux" ]; then
            echo -e "${RED}Please install Python 3.10+ manually${NC}"
            echo "Ubuntu: sudo apt install python3.11 python3.11-venv"
            exit 1
        fi
    fi
else
    echo -e "${YELLOW}Python not found. Installing...${NC}"
    if [ "$OS" == "macos" ]; then
        install_brew "python@3.11"
    elif [ "$OS" == "linux" ]; then
        sudo apt-get update
        sudo apt-get install -y python3 python3-venv python3-pip
    fi
fi

# ============================================
# 3. Setup Python Virtual Environment
# ============================================
echo ""
echo "[3/7] Setting up Python virtual environment..."

if [ -d "$REPO_ROOT/.venv" ] && [ "$FORCE" = false ]; then
    echo -e "${GREEN}✓ Virtual environment already exists${NC}"
else
    if [ "$FORCE" = true ] && [ -d "$REPO_ROOT/.venv" ]; then
        echo -e "${YELLOW}Removing existing venv (force mode)...${NC}"
        rm -rf "$REPO_ROOT/.venv"
    fi
    
    echo -e "${YELLOW}Creating virtual environment...${NC}"
    python3 -m venv "$REPO_ROOT/.venv"
    echo -e "${GREEN}✓ Virtual environment created${NC}"
fi

# Activate for this script
source "$REPO_ROOT/.venv/bin/activate"

# Upgrade pip
pip install --quiet --upgrade pip

# Install Python dependencies
echo -e "${YELLOW}Installing Python dependencies...${NC}"
if [ -f "$REPO_ROOT/requirements.txt" ]; then
    pip install --quiet -r "$REPO_ROOT/requirements.txt"
    echo -e "${GREEN}✓ Python dependencies installed${NC}"
else
    echo -e "${YELLOW}No requirements.txt found, skipping pip installs${NC}"
fi

# ============================================
# 4. Install Terraform
# ============================================
echo ""
echo "[4/7] Checking Terraform..."

if command_exists terraform; then
    TF_VERSION=$(terraform version -json 2>/dev/null | grep -o '"terraform_version":"[^"]*"' | cut -d'"' -f4 || terraform version | head -1)
    echo -e "${GREEN}✓ Terraform $TF_VERSION installed${NC}"
else
    echo -e "${YELLOW}Installing Terraform...${NC}"
    
    if [ "$OS" == "macos" ]; then
        install_brew "terraform"
    elif [ "$OS" == "linux" ]; then
        # Install Terraform on Linux
        curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
        sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
        sudo apt-get update
        sudo apt-get install -y terraform
    fi
    
    echo -e "${GREEN}✓ Terraform installed${NC}"
fi

# ============================================
# 5. Install Ansible
# ============================================
echo ""
echo "[5/7] Checking Ansible..."

if command_exists ansible-playbook; then
    ANSIBLE_VERSION=$(ansible --version | head -1)
    echo -e "${GREEN}✓ $ANSIBLE_VERSION installed${NC}"
else
    echo -e "${YELLOW}Installing Ansible...${NC}"
    pip install --quiet ansible
    echo -e "${GREEN}✓ Ansible installed${NC}"
fi

# ============================================
# 6. Install AWS CLI
# ============================================
echo ""
echo "[6/7] Checking AWS CLI..."

if command_exists aws; then
    AWS_VERSION=$(aws --version | cut -d' ' -f1)
    echo -e "${GREEN}✓ AWS CLI $AWS_VERSION installed${NC}"
    
    # Check if credentials are configured
    if aws sts get-caller-identity &> /dev/null; then
        AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
        echo -e "${GREEN}✓ AWS credentials configured (Account: $AWS_ACCOUNT)${NC}"
    else
        echo -e "${YELLOW}⚠ AWS CLI installed but credentials not configured${NC}"
        echo "  Run: aws configure"
        echo "  Get credentials from: https://console.aws.amazon.com/iam/home#/security_credentials"
    fi
else
    echo -e "${YELLOW}Installing AWS CLI...${NC}"
    
    if [ "$OS" == "macos" ]; then
        install_brew "awscli"
    elif [ "$OS" == "linux" ]; then
        curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
        unzip -q /tmp/awscliv2.zip -d /tmp
        sudo /tmp/aws/install
        rm -rf /tmp/aws /tmp/awscliv2.zip
    fi
    
    echo -e "${GREEN}✓ AWS CLI installed${NC}"
    echo -e "${YELLOW}⚠ Please configure AWS credentials:${NC}"
    echo "  aws configure"
fi

# ============================================
# 7. Install Optional Tools
# ============================================
echo ""
echo "[7/7] Checking optional tools..."

# MAVProxy (useful for debugging)
if command_exists mavproxy.py; then
    echo -e "${GREEN}✓ MAVProxy installed${NC}"
else
    echo -e "${YELLOW}Installing MAVProxy...${NC}"
    pip install --quiet MAVProxy
    echo -e "${GREEN}✓ MAVProxy installed${NC}"
fi

# yamllint (for CI)
if command_exists yamllint; then
    echo -e "${GREEN}✓ yamllint installed${NC}"
else
    echo -e "${YELLOW}Installing yamllint...${NC}"
    pip install --quiet yamllint
    echo -e "${GREEN}✓ yamllint installed${NC}"
fi

# ============================================
# Summary
# ============================================
echo ""
echo "=========================================="
echo -e "${GREEN}  Development Environment Ready!${NC}"
echo "=========================================="
echo ""
echo "Virtual Environment: $REPO_ROOT/.venv"
echo "To activate: source .venv/bin/activate"
echo ""
echo "Quick Start:"
echo "  1. Activate: source .venv/bin/activate"
echo "  2. Setup AWS: aws configure"
echo "  3. Deploy SITL: cd infra/scripts && ./setup-cloud-sitl.sh"
echo ""
echo "Or use the all-in-one command:"
echo "  ./quickstart.sh"
echo ""

# Create activation reminder
cat > "$REPO_ROOT/.env-activate" << 'EOF'
#!/bin/bash
# Quick activation script
cd "$(dirname "$0")"
source .venv/bin/activate
exec "$@"
EOF

chmod +x "$REPO_ROOT/.env-activate"

echo "Tip: Use ./.env-activate <command> to run commands in the venv"
echo "  Example: ./.env-activate python -m adapters.vehicle_adapter --help"
echo ""
