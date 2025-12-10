#!/bin/bash

# ==========================================
# Ostris AI Toolkit - Stable Installer (4070 Ti Super)
# Method: Direct Path Execution (No Activation Needed)
# Includes: Stable Torch, Missing Utils, Memory Fixes
# ==========================================

echo ">>> Detecting Conda Installation..."
# Auto-detect where Conda lives
CONDA_BASE=$(conda info --base 2>/dev/null)
if [ -z "$CONDA_BASE" ]; then
    # Fallbacks if 'conda' command not found
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
echo ">>> Setting up 'toolkit' environment..."
conda deactivate 2>/dev/null
conda env remove -n toolkit -y 2>/dev/null
conda create -n toolkit python=3.10 -y

# DEFINE DIRECT PATHS (The Fix)
# We use these variables to install directly into the new env
TK_PIP="$CONDA_BASE/envs/toolkit/bin/pip"
TK_PYTHON="$CONDA_BASE/envs/toolkit/bin/python"

# Verify paths exist
if [ ! -f "$TK_PIP" ]; then
    # Try finding it via conda env list if standard path fails
    TK_ENV_PATH=$(conda env list | grep -w "toolkit" | awk '{print $NF}' | head -n 1)
    TK_PIP="$TK_ENV_PATH/bin/pip"
    TK_PYTHON="$TK_ENV_PATH/bin/python"
fi

if [ ! -f "$TK_PIP" ]; then
    echo "CRITICAL ERROR: Could not locate pip for the new environment."
    exit 1
fi
echo ">>> Targeted Install Path: $TK_PIP"

# --- STEP 2: CLONE REPO ---
cd /workspace
echo ">>> Cloning Repository..."
rm -rf ai-toolkit
git clone --depth 1 https://github.com/ostris/ai-toolkit
cd ai-toolkit

# --- STEP 3: INSTALL DEPENDENCIES (STABLE) ---
echo ">>> Installing Python Packages..."

# 1. Upgrade Pip
"$TK_PYTHON" -m pip install --upgrade pip

# 2. Install Torch STABLE (CUDA 12.4) - Best for 4070 Ti Super
echo ">>> Installing Torch Stable..."
"$TK_PIP" install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu124

# 3. Install Toolkit Requirements
echo ">>> Installing Requirements.txt..."
"$TK_PIP" install -r requirements.txt

# 4. Install MISSING UTILITIES (The fixes for your errors)
# Added 'lpips' to this list
echo ">>> Installing Utilities (dotenv, oyaml, prodict, lpips)..."
"$TK_PIP" install python-dotenv opencv-python tensorboard ftfy albumentations lycoris_lora oyaml prodict einops imageio safetensors invisible-watermark lpips

# 5. Patch Transformers
echo ">>> Patching Transformers..."
"$TK_PIP" install -U transformers diffusers accelerate peft huggingface_hub[cli] protobuf

# --- STEP 4: MEMORY FIXES ---
echo ">>> Applying Memory Fixes..."
# We briefly activate to set the permanent var
conda activate toolkit
conda env config vars set PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True,max_split_size_mb:512
conda deactivate

# --- STEP 5: UI SETUP ---
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
echo "   INSTALLATION SUCCESSFUL"
echo "========================================================"
echo "1. Activate:  conda activate toolkit"
echo "2. Start UI:  cd /workspace/ai-toolkit/ui && npm run start"
echo "========================================================"
