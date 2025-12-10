#!/bin/bash

# ==========================================
# Ostris AI Toolkit - 50-SERIES INSTALLER (RTX 5080 / 5090)
# Engine: Torch 2.8.0 Nightly + CUDA 12.9
# ==========================================

echo ">>> Detecting Conda Installation..."
CONDA_BASE=$(conda info --base 2>/dev/null)
if [ -z "$CONDA_BASE" ]; then
    if [ -d "/opt/conda" ]; then CONDA_BASE="/opt/conda"; fi
    if [ -d "/root/miniconda3" ]; then CONDA_BASE="/root/miniconda3"; fi
    if [ -d "$HOME/miniconda3" ]; then CONDA_BASE="$HOME/miniconda3"; fi
fi

if [ -z "$CONDA_BASE" ]; then
    echo "CRITICAL ERROR: Could not find Conda. Exiting."
    exit 1
fi
echo ">>> Found Conda at: $CONDA_BASE"
source "$CONDA_BASE/etc/profile.d/conda.sh"

# --- STEP 1: CLEAN & CREATE ENVIRONMENT ---
echo ">>> Setting up 'toolkit' environment (Python 3.10)..."
conda deactivate 2>/dev/null
conda env remove -n toolkit -y 2>/dev/null
# Python 3.10 is STRICTLY REQUIRED for the 50-series custom wheels
conda create -n toolkit python=3.10 -y

# DEFINE DIRECT PATHS
TK_PIP="$CONDA_BASE/envs/toolkit/bin/pip"
TK_PYTHON="$CONDA_BASE/envs/toolkit/bin/python"

if [ ! -f "$TK_PIP" ]; then
    TK_ENV_PATH=$(conda env list | grep -w "toolkit" | awk '{print $NF}' | head -n 1)
    TK_PIP="$TK_ENV_PATH/bin/pip"
    TK_PYTHON="$TK_ENV_PATH/bin/python"
fi

if [ ! -f "$TK_PIP" ]; then
    echo "CRITICAL ERROR: Could not locate pip."
    exit 1
fi
echo ">>> Targeted Install Path: $TK_PIP"

# --- STEP 2: CLONE REPO ---
cd /workspace
echo ">>> Cloning Repository..."
rm -rf ai-toolkit
git clone --depth 1 https://github.com/ostris/ai-toolkit
cd ai-toolkit

# --- STEP 3: GENERATE 50-SERIES REQUIREMENTS ---
echo ">>> Writing Custom Requirements (MonsterMMORPG Wheels)..."
cat <<EOF > requirements.txt
--extra-index-url https://download.pytorch.org/whl/cu129
torch==2.8.0
torchvision
torchaudio
flash_attn @ https://huggingface.co/MonsterMMORPG/Wan_GGUF/resolve/main/flash_attn-2.8.2-cp310-cp310-linux_x86_64.whl ; sys_platform == 'linux'
xformers @ https://huggingface.co/MonsterMMORPG/Wan_GGUF/resolve/main/xformers-0.0.33+c159edc0.d20250906-cp39-abi3-linux_x86_64.whl ; sys_platform == 'linux'
sageattention @ https://huggingface.co/MonsterMMORPG/Wan_GGUF/resolve/main/sageattention-2.2.0-cp39-abi3-linux_x86_64.whl ; sys_platform == 'linux'
hf_xet
EOF

# --- STEP 4: INSTALL DEPENDENCIES (NIGHTLY) ---
echo ">>> Installing Python Packages..."

# 1. Upgrade Pip
"$TK_PYTHON" -m pip install --upgrade pip

# 2. Install Torch NIGHTLY (CUDA 12.9) - REQUIRED for 5080
echo ">>> Installing Torch Nightly (2.8.0)..."
"$TK_PIP" install "torch==2.8.0" torchvision torchaudio --extra-index-url https://download.pytorch.org/whl/cu129

# 3. Install Custom Wheels
echo ">>> Installing Custom Wheels..."
"$TK_PIP" install -r requirements.txt

# 4. Install UTILITIES
echo ">>> Installing Utilities..."
"$TK_PIP" install python-dotenv opencv-python tensorboard ftfy albumentations lycoris_lora oyaml prodict einops imageio safetensors invisible-watermark

# 5. Patch Transformers
echo ">>> Patching Transformers..."
"$TK_PIP" install -U transformers diffusers accelerate peft huggingface_hub[cli] protobuf --extra-index-url https://download.pytorch.org/whl/cu129

# --- STEP 5: MEMORY FIXES ---
echo ">>> Applying Memory Fixes..."
conda activate toolkit
conda env config vars set PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True,max_split_size_mb:512
conda deactivate

# --- STEP 6: UI SETUP ---
echo ">>> Installing Node.js v22..."
apt-get update -qq
apt-get purge nodejs -y 2>/dev/null
apt-get autoremove -y 2>/dev/null
apt-get install -y ca-certificates curl gnupg

mkdir -p /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list

apt-get update -qq
apt-get install nodejs -y

echo ">>> Building UI..."
cd /workspace/ai-toolkit/ui
rm -rf node_modules .next dist
npm install
npm run update_db
npm run build

echo "========================================================"
echo "   50-SERIES INSTALLATION SUCCESSFUL"
echo "========================================================"
echo "1. Activate:  conda activate toolkit"
echo "2. Start UI:  cd /workspace/ai-toolkit/ui && npm run start"
echo "========================================================"
