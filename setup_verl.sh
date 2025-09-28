#!/bin/bash

# Exit on error
set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting Ubuntu Server Setup for VERL Project${NC}"
echo "=================================================="

# Function to print colored messages
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# 1. Update packages
print_status "Updating system packages..."
export DEBIAN_FRONTEND=noninteractive
apt update -y
apt upgrade -y
apt dist-upgrade -y

# 2. Check and install CUDA if needed
print_status "Checking CUDA installation..."
CUDA_VERSION_REQUIRED="12.4"
CUDA_INSTALLED=false
CURRENT_CUDA_VERSION=""

if command -v nvcc &> /dev/null; then
    CURRENT_CUDA_VERSION=$(nvcc --version | grep "release" | awk '{print $6}' | cut -d',' -f1)
    print_status "Found CUDA version: $CURRENT_CUDA_VERSION"
    CUDA_INSTALLED=true
    
    # Compare versions
    if [ "$(printf '%s\n' "$CUDA_VERSION_REQUIRED" "$CURRENT_CUDA_VERSION" | sort -V | head -n1)" != "$CUDA_VERSION_REQUIRED" ]; then
        print_warning "CUDA version is less than $CUDA_VERSION_REQUIRED. Installing CUDA 12.4..."
        CUDA_INSTALLED=false
    fi
else
    print_warning "CUDA not found. Installing CUDA 12.4..."
fi

if [ "$CUDA_INSTALLED" = false ]; then
    print_status "Downloading and installing CUDA 12.4..."
    wget -q https://developer.download.nvidia.com/compute/cuda/12.4.1/local_installers/cuda-repo-ubuntu2204-12-4-local_12.4.1-550.54.15-1_amd64.deb
    dpkg -i cuda-repo-ubuntu2204-12-4-local_12.4.1-550.54.15-1_amd64.deb
    cp /var/cuda-repo-ubuntu2204-12-4-local/cuda-*-keyring.gpg /usr/share/keyrings/
    apt-get update
    apt-get -y install cuda-toolkit-12-4
    update-alternatives --set cuda /usr/local/cuda-12.4
    
    # Add CUDA to PATH
    echo 'export PATH=/usr/local/cuda-12.4/bin:$PATH' >> ~/.bashrc
    echo 'export LD_LIBRARY_PATH=/usr/local/cuda-12.4/lib64:$LD_LIBRARY_PATH' >> ~/.bashrc
    export PATH=/usr/local/cuda-12.4/bin:$PATH
    export LD_LIBRARY_PATH=/usr/local/cuda-12.4/lib64:$LD_LIBRARY_PATH
    
    # Clean up
    rm -f cuda-repo-ubuntu2204-12-4-local_12.4.1-550.54.15-1_amd64.deb
fi

# 3. Check and install cuDNN if needed
print_status "Checking cuDNN installation..."
CUDNN_VERSION_REQUIRED="9.8.0"
CUDNN_INSTALLED=false

# Check if cuDNN is installed using multiple methods
# Method 1: Check for cudnn_version.h header file
if [ -f "/usr/include/cudnn_version.h" ] || [ -f "/usr/local/cuda/include/cudnn_version.h" ] || [ -f "/usr/include/x86_64-linux-gnu/cudnn_version.h" ]; then
    if [ -f "/usr/include/cudnn_version.h" ]; then
        CUDNN_HEADER="/usr/include/cudnn_version.h"
    elif [ -f "/usr/local/cuda/include/cudnn_version.h" ]; then
        CUDNN_HEADER="/usr/local/cuda/include/cudnn_version.h"
    else
        CUDNN_HEADER="/usr/include/x86_64-linux-gnu/cudnn_version.h"
    fi
    
    CUDNN_MAJOR=$(grep CUDNN_MAJOR $CUDNN_HEADER 2>/dev/null | head -1 | awk '{print $3}')
    CUDNN_MINOR=$(grep CUDNN_MINOR $CUDNN_HEADER 2>/dev/null | head -1 | awk '{print $3}')
    CUDNN_PATCHLEVEL=$(grep CUDNN_PATCHLEVEL $CUDNN_HEADER 2>/dev/null | head -1 | awk '{print $3}')
    
    if [ ! -z "$CUDNN_MAJOR" ]; then
        CURRENT_CUDNN_VERSION="${CUDNN_MAJOR}.${CUDNN_MINOR}.${CUDNN_PATCHLEVEL}"
        print_status "Found cuDNN version: $CURRENT_CUDNN_VERSION"
        CUDNN_INSTALLED=true
        
        # Compare versions
        if [ "$(printf '%s\n' "$CUDNN_VERSION_REQUIRED" "$CURRENT_CUDNN_VERSION" | sort -V | head -n1)" != "$CUDNN_VERSION_REQUIRED" ]; then
            print_warning "cuDNN version is less than $CUDNN_VERSION_REQUIRED. Installing cuDNN 9.8.0..."
            CUDNN_INSTALLED=false
        fi
    fi
fi

# Method 2: Check using dpkg if header method failed
if [ "$CUDNN_INSTALLED" = false ]; then
    CUDNN_PKG=$(dpkg -l | grep -E "libcudnn[0-9]+-cuda-" | awk '{print $2, $3}')
    if [ ! -z "$CUDNN_PKG" ]; then
        CUDNN_VERSION=$(echo "$CUDNN_PKG" | awk '{print $2}' | cut -d'-' -f1)
        print_status "Found cuDNN package version: $CUDNN_VERSION"
        if [ ! -z "$CUDNN_VERSION" ]; then
            CUDNN_INSTALLED=true
            # Compare versions
            if [ "$(printf '%s\n' "$CUDNN_VERSION_REQUIRED" "$CUDNN_VERSION" | sort -V | head -n1)" != "$CUDNN_VERSION_REQUIRED" ]; then
                print_warning "cuDNN version is less than $CUDNN_VERSION_REQUIRED. Will attempt to install cuDNN 9.8.0..."
                CUDNN_INSTALLED=false
            fi
        fi
    else
        print_warning "cuDNN not found. Installing cuDNN 9.8.0..."
    fi
fi

if [ "$CUDNN_INSTALLED" = false ]; then
    print_status "Preparing cuDNN 9.8.0 installation..."
    
    # First, remove any conflicting cuDNN packages
    print_status "Removing conflicting cuDNN packages if any..."
    apt-get remove -y libcudnn9-dev-cuda-12 libcudnn9-cuda-12 2>/dev/null || true
    apt-get autoremove -y 2>/dev/null || true
    
    # Download and install cuDNN
    print_status "Downloading and installing cuDNN 9.8.0..."
    wget -q https://developer.download.nvidia.com/compute/cudnn/9.8.0/local_installers/cudnn-local-repo-ubuntu2204-9.8.0_1.0-1_amd64.deb
    dpkg -i cudnn-local-repo-ubuntu2204-9.8.0_1.0-1_amd64.deb
    
    # Copy the keyring
    cp /var/cudnn-local-repo-ubuntu2204-9.8.0/cudnn-*-keyring.gpg /usr/share/keyrings/ 2>/dev/null || true
    
    # Update package list
    apt-get update
    
    # Install specific version of cuDNN
    apt-get -y install libcudnn9-cuda-12=9.8.0.87-1 || {
        print_warning "Standard installation failed, trying alternative method..."
        apt-get -y install --allow-downgrades libcudnn9-cuda-12=9.8.0.87-1 || {
            print_warning "Downgrade failed, installing available version..."
            apt-get -y install libcudnn9-cuda-12
        }
    }
    
    # Clean up
    rm -f cudnn-local-repo-ubuntu2204-9.8.0_1.0-1_amd64.deb
fi

# 4. Install nano, tmux and nvitop
print_status "Installing nano and tmux..."
apt install nano -y
apt install tmux -y
pip3 install --upgrade nvitop

# 5. Install UV
print_status "Installing UV..."
curl -LsSf https://astral.sh/uv/install.sh | sh

# Add UV to PATH
export PATH="$HOME/.local/bin:$PATH"
source $HOME/.local/bin/env 2>/dev/null || true

# Verify UV installation
if ! command -v uv &> /dev/null; then
    print_warning "UV not found in PATH, attempting to add it..."
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
    source ~/.bashrc
fi

# 6. Initialize UV project
print_status "Initializing UV project..."

# Ensure UV is available
if ! command -v uv &> /dev/null; then
    print_error "UV command not found. Please ensure UV is installed and in PATH."
    print_status "You may need to run: source $HOME/.local/bin/env"
    exit 1
fi

if [ -d "verl_project" ]; then
    print_warning "verl_project directory already exists. Removing old project..."
    rm -rf verl_project
fi

uv init verl_project
cd verl_project

# Try to install Python 3.12, fallback to available versions
print_status "Installing Python 3.12..."
if ! uv python install 3.12; then
    print_warning "Python 3.12 not available, trying Python 3.11..."
    if ! uv python install 3.11; then
        print_warning "Python 3.11 not available, using system Python..."
        uv python install
    fi
fi

# Pin the installed Python version
PYTHON_VERSION=$(uv python list | grep -E '^\*' | awk '{print $2}' | head -1)
if [ ! -z "$PYTHON_VERSION" ]; then
    print_status "Pinning Python version: $PYTHON_VERSION"
    uv python pin $PYTHON_VERSION
else
    print_status "Using default Python version"
fi

uv sync

# 7. Add libraries
print_status "Adding Jupyter and notebook to UV project..."
uv add jupyter notebook

# 8. Activate environment
print_status "Activating virtual environment..."
source .venv/bin/activate

# Store the virtual environment path for later use
VENV_PATH="$(pwd)/.venv"
export VENV_PATH

# 9. Clone and install VERL
print_status "Cloning and installing VERL..."
if [ -d "verl" ]; then
    print_warning "verl directory already exists. Removing old installation..."
    rm -rf verl
fi

git clone https://github.com/volcengine/verl.git
cd verl

# Install vllm and sglang
USE_MEGATRON=0 bash scripts/install_vllm_sglang_mcore.sh

# Install torch first if needed
uv pip install torch

# Install flash-attn without build isolation (it needs torch during build)
print_status "Installing flash-attn (this may take a while)..."
uv pip install flash-attn --no-build-isolation || {
    print_warning "flash-attn installation failed, trying alternative method..."
    # Try to install a pre-built wheel if available
    uv pip install flash-attn || print_warning "flash-attn installation skipped"
}

# Install VERL requirements if requirements.txt exists
if [ -f "requirements.txt" ]; then
    print_status "Installing VERL requirements from requirements.txt..."
    uv pip install -r requirements.txt || {
        print_warning "Some requirements failed to install, trying without deps..."
        uv pip install -r requirements.txt --no-deps || print_warning "Some dependencies may be missing"
    }
else
    print_warning "requirements.txt not found, skipping requirements installation"
fi

# Install VERL
uv pip install --no-deps -e .

cd ..

# 10. Add vLLM
print_status "Adding vLLM..."
uv add vllm

# 11. Install Apex (after environment is set up)
print_status "Installing NVIDIA Apex..."

if [ -d "apex" ]; then
    print_warning "Apex directory already exists. Removing old installation..."
    rm -rf apex
fi

git clone https://github.com/NVIDIA/apex.git

# Since UV manages packages differently, let's use UV to install Apex
print_status "Installing Apex using UV package manager..."
cd apex

# First, try using UV's pip interface
if command -v uv &> /dev/null; then
    print_status "Using UV pip to install Apex..."
    MAX_JOBS=32 uv pip install -v --no-build-isolation ./
else
    print_error "UV not found. Apex installation skipped."
    print_status "To install Apex manually, run:"
    print_status "  cd apex"
    print_status "  uv pip install -v --no-build-isolation ./"
fi

cd ..

# 12. Configure Jupyter for remote session
print_status "Configuring Jupyter for remote access..."
jupyter notebook --generate-config

# 13. Add configuration to jupyter_notebook_config.py
cat > ~/.jupyter/jupyter_notebook_config.py << 'EOF'
c = get_config()

c.NotebookApp.ip = '*'
c.NotebookApp.open_browser = False
c.NotebookApp.port = 5000
c.NotebookApp.allow_remote_access = True
c.NotebookApp.allow_origin = '*'
EOF

# 14. Start Jupyter in tmux
print_status "Starting Jupyter notebook in tmux session..."
tmux new-session -d -s jupyter "cd $(pwd) && source .venv/bin/activate && jupyter notebook --port 5000 --no-browser --allow-root 2>&1 | tee jupyter.log"

# Wait for Jupyter to start and capture the token
sleep 5

# Get the Jupyter URL with token
JUPYTER_URL=$(grep -o 'http://.*:5000/.*token=[a-z0-9]*' jupyter.log | tail -1)
if [ -z "$JUPYTER_URL" ]; then
    JUPYTER_URL=$(jupyter notebook list | grep ':5000' | awk '{print $1}')
fi

# Extract token from URL
TOKEN=$(echo $JUPYTER_URL | grep -o 'token=[a-z0-9]*' | cut -d'=' -f2)

# 15. Display installation summary
echo ""
echo "=========================================="
echo -e "${GREEN}Installation Complete!${NC}"
echo "=========================================="
echo ""

# Get system information
UBUNTU_VERSION=$(lsb_release -d | awk -F'\t' '{print $2}')

# Get Python version - try multiple methods
PYTHON_VERSION=""
if [ -f ".venv/bin/python" ]; then
    PYTHON_VERSION=$(.venv/bin/python --version 2>&1 | awk '{print $2}')
elif command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
else
    PYTHON_VERSION="Not detected"
fi

# Get PyTorch version
PYTORCH_VERSION=""
if [ -f ".venv/bin/python" ]; then
    PYTORCH_VERSION=$(.venv/bin/python -c "import torch; print(torch.__version__)" 2>/dev/null || echo "Not installed")
else
    PYTORCH_VERSION=$(python3 -c "import torch; print(torch.__version__)" 2>/dev/null || echo "Not installed")
fi

# Get vLLM version
VLLM_VERSION=""
if [ -f ".venv/bin/python" ]; then
    VLLM_VERSION=$(.venv/bin/python -c "import vllm; print(vllm.__version__)" 2>/dev/null || echo "Not installed")
else
    VLLM_VERSION=$(python3 -c "import vllm; print(vllm.__version__)" 2>/dev/null || echo "Not installed")
fi

CUDA_VERSION=$(nvcc --version 2>/dev/null | grep "release" | awk '{print $6}' | cut -d',' -f1 || echo "Not detected")

# Try multiple methods to detect cuDNN version
CUDNN_VERSION="Not detected"
# Method 1: Python/PyTorch
if [ -f ".venv/bin/python" ]; then
    CUDNN_VERSION=$(.venv/bin/python -c "import torch; print(torch.backends.cudnn.version())" 2>/dev/null || echo "")
else
    CUDNN_VERSION=$(python3 -c "import torch; print(torch.backends.cudnn.version())" 2>/dev/null || echo "")
fi
# Method 2: Check header file
if [ -z "$CUDNN_VERSION" ] || [ "$CUDNN_VERSION" = "" ]; then
    for header in "/usr/include/cudnn_version.h" "/usr/local/cuda/include/cudnn_version.h" "/usr/include/x86_64-linux-gnu/cudnn_version.h"; do
        if [ -f "$header" ]; then
            CUDNN_MAJOR=$(grep CUDNN_MAJOR $header 2>/dev/null | head -1 | awk '{print $3}')
            CUDNN_MINOR=$(grep CUDNN_MINOR $header 2>/dev/null | head -1 | awk '{print $3}')
            CUDNN_PATCHLEVEL=$(grep CUDNN_PATCHLEVEL $header 2>/dev/null | head -1 | awk '{print $3}')
            if [ ! -z "$CUDNN_MAJOR" ]; then
                CUDNN_VERSION="${CUDNN_MAJOR}.${CUDNN_MINOR}.${CUDNN_PATCHLEVEL}"
                break
            fi
        fi
    done
fi
# Method 3: Check package version
if [ -z "$CUDNN_VERSION" ] || [ "$CUDNN_VERSION" = "" ]; then
    CUDNN_VERSION=$(dpkg -l | grep -E "libcudnn[0-9]+-cuda-" | awk '{print $3}' | cut -d'-' -f1 | head -1)
    [ -z "$CUDNN_VERSION" ] && CUDNN_VERSION="Not detected"
fi

# Get Apex version
APEX_VERSION=""
if [ -f ".venv/bin/python" ]; then
    APEX_VERSION=$(.venv/bin/python -c "import apex; print('Installed')" 2>/dev/null || echo "Not installed")
else
    APEX_VERSION=$(python3 -c "import apex; print('Installed')" 2>/dev/null || echo "Not installed")
fi

CUDA_DEVICES=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | wc -l || echo "0")
GPU_NAMES=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | paste -sd ", " || echo "No GPUs detected")

echo -e "${GREEN}System Information:${NC}"
echo "==================="
echo "Ubuntu Version: $UBUNTU_VERSION"
echo "Python Version: $PYTHON_VERSION"
echo "PyTorch Version: $PYTORCH_VERSION"
echo "CUDA Version: $CUDA_VERSION"
echo "cuDNN Version: $CUDNN_VERSION"
echo "vLLM Version: $VLLM_VERSION"
echo "Apex: $APEX_VERSION"
echo "CUDA Devices: $CUDA_DEVICES GPU(s) available"
echo "GPU Names: $GPU_NAMES"
echo ""

echo -e "${GREEN}Jupyter Notebook Access:${NC}"
echo "========================"
echo "Jupyter is running in tmux session 'jupyter'"
echo ""
echo "Local URL with token:"
echo "http://localhost:5000/?token=$TOKEN"
echo ""
echo -e "${YELLOW}To access from your local computer, run:${NC}"
echo "ssh -N -f -L localhost:5000:localhost:5000 <your_username>@<your_server_ip>"
echo ""
echo "Then open in your browser:"
echo "http://localhost:5000/?token=$TOKEN"
echo ""
echo -e "${GREEN}Other useful commands:${NC}"
echo "======================"
echo "View Jupyter logs: tmux attach -t jupyter"
echo "Detach from tmux: Press Ctrl+B, then D"
echo "Kill Jupyter session: tmux kill-session -t jupyter"
echo ""
echo "Project location: $(pwd)"
echo "Activate environment: source $(pwd)/.venv/bin/activate"
echo ""
echo -e "${GREEN}Setup complete! Enjoy your VERL project!${NC}"
