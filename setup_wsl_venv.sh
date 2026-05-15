#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Stretch AI WSL setup script
#
# Purpose:
# Build a clean WSL Ubuntu runtime for the Stretch voice-control
# project. This environment is called by the Windows-side
# voice_master_v2.py program during robot execution.
#
# Overall system design:
#   Windows:
#     microphone input, Whisper transcription, hotkeys,
#     LLM intent parsing
#
#   WSL Ubuntu:
#     Stretch AI client logic, grasp pipeline, teleoperation
#     command dispatch
#
#   Stretch Robot:
#     ROS2/ZMQ bridge and physical robot execution
#
# This split keeps the robot lightweight and avoids putting
# speech recognition or LLM logic directly on the robot.
#
# Creates:
#   ~/stretch_ai
#   ~/stretch_ai/venv
#
# IMPORTANT:
# This script only installs the runtime environment.
#
# After installation, manually replace the following customized
# project files:
#
#   ~/stretch_ai/task2_client.py
#   ~/stretch_ai/src/stretch/perception/encoders/siglip_encoder.py
#   ~/stretch_ai/src/stretch/app/grasp_object.py
#   ~/stretch_ai/src/stretch/agent/robot_agent_dynamem.py
#
# Reason:
# The original Stretch AI repository provides the baseline
# framework. These replacement files contain the project-specific
# behavior used for voice control, grasp execution, perception
# encoding, and robot-agent logic.
#
# Keeping setup and customized behavior separate makes the
# installation easier to reproduce and easier to update later.
# ============================================================

REPO_DIR="$HOME/stretch_ai"

# Directory containing this script.
# Used so requirement files can be loaded relative to this script
# instead of using hardcoded user-specific paths such as /home/xxx.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Pinned runtime requirements for the WSL environment.
# These versions were separated into a file so future users can
# inspect or update dependencies without editing this setup script.
REQ_FILE="$SCRIPT_DIR/wsl_venv_requirements.txt"


echo "[1/8] Installing Ubuntu dependencies..."

# Install system-level dependencies needed by Stretch AI, Python,
# audio libraries, OpenCV/visualization tools, and basic network tests.
# Some packages are included to prevent common missing-library errors
# during later runtime, not because they are directly called here.
sudo apt update

sudo apt install -y \
  git git-lfs curl wget build-essential python3-dev python3-venv python3-pip \
  ffmpeg libsm6 libxext6 \
  libasound-dev portaudio19-dev libportaudio2 libportaudiocpp0 \
  iputils-ping espeak libxkbcommon-x11-0


echo "[2/8] Cloning or updating Stretch AI..."

# Clone the Stretch AI repository if it does not already exist.
# If it already exists, update it and make sure submodules are present.
# Recursive submodules are important because an incomplete clone can
# lead to missing-package or missing-source errors later.
if [ ! -d "$REPO_DIR/.git" ]; then
  git clone https://github.com/hello-robot/stretch_ai.git --recursive "$REPO_DIR"
else
  cd "$REPO_DIR"
  git pull
  git submodule update --init --recursive
fi


cd "$REPO_DIR"

echo "[3/8] Creating Python venv..."

# Create a dedicated Python virtual environment for this project.
# This avoids conflicts with system Python, Conda environments, or
# packages installed for other robot projects.
python3 -m venv venv
source "$REPO_DIR/venv/bin/activate"


echo "[4/8] Updating pip..."

# Upgrade packaging tools before installing large dependencies.
# This reduces avoidable installation and dependency-resolution issues.
python -m pip install --upgrade pip setuptools wheel


echo "[5/8] Installing PyTorch..."

# Install the CUDA 11.8 PyTorch build used by this deployment path.
# Keeping this step explicit makes the GPU-related dependency choice clear.
pip install torch torchvision torchaudio \
--index-url https://download.pytorch.org/whl/cu118


echo "[6/8] Installing Stretch AI..."

# Install Stretch AI in editable mode.
# Editable installation is useful because the project replaces/modifies
# several source files after setup, and changes should take effect without
# reinstalling the package each time.
cd "$REPO_DIR/src"
pip install -e ".[dev]"


echo "[7/8] Installing project requirements..."

# Install project-specific pinned Python packages.
# These requirements capture the final working versions after debugging.
pip install -r "$REQ_FILE"


echo "[7.5/8] Fixing boost dependency..."

# Compatibility override for boost-related dependency issues observed
# during setup. The --no-deps flag avoids pulling additional dependency
# changes after the main environment has already been pinned.
pip install cmeel-boost==1.89.0 --no-deps


echo "[7.6/8] Applying rerun patch..."

# Patch a Rerun visualization issue where theta may appear as a tensor-like
# object instead of a plain scalar. This can break visualization even when
# the robot pipeline itself is otherwise working.
#
# The patch is safe to rerun:
#   - if the file already contains the fixed form, nothing changes
#   - if the file is missing, setup continues and reports it
python - <<'PY'
from pathlib import Path

p = Path.home() / "stretch_ai/src/stretch/visualization/rerun.py"

if p.exists():

    s=p.read_text()

    s2=s

    s2=s2.replace(
        "radians=float(theta),",
        "radians=float(theta.item() if hasattr(theta,'item') else theta),"
    )

    s2=s2.replace(
        "radians=theta,",
        "radians=float(theta.item() if hasattr(theta,'item') else theta),"
    )

    if s2!=s:
        p.write_text(s2)
        print("Patch applied")

    else:
        print("Patch already exists")

else:
    print("rerun.py not found")
PY


echo "[8/8] Running smoke test..."

cd "$REPO_DIR"

# Import smoke test.
# This catches broken installs before running robot commands.
# It checks the main packages used by the WSL-side Stretch AI runtime.
python - <<'PY'
import numpy
import torch
import rerun
import cv2
import transformers
import stretch

print("OK: Stretch AI imports passed")
print("numpy:",numpy.__version__)
print("torch:",torch.__version__,"cuda:",torch.cuda.is_available())
print("opencv:",cv2.__version__)
print("transformers:",transformers.__version__)
PY


echo
echo "Done."
echo

echo "Activate:"
echo "source ~/stretch_ai/venv/bin/activate"

echo
echo "Test:"

echo "cd ~/stretch_ai/src"

echo 'python -m stretch.app.grasp_object --target_object "pink bottle" --robot_ip 172.22.243.38'
