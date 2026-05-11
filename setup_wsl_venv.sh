#!/usr/bin/env bash
set -euo pipefail

# WSL Ubuntu 22.04 setup for the local Stretch AI venv used by Windows voice_master_v2.py.
# Expected final path:
#   ~/stretch_ai/venv
#   ~/stretch_ai/src
#
# After this setup, manually replace:
#   ~/stretch_ai/task2_client.py
#   ~/stretch_ai/src/stretch/perception/encoders/siglip_encoder.py
#   ~/stretch_ai/src/stretch/app/grasp_object.py
#   ~/stretch_ai/src/stretch/agent/robot_agent_dynamem.py

REPO_DIR="$HOME/stretch_ai"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REQ_FILE="$SCRIPT_DIR/wsl_venv_requirements.txt"

echo "[1/8] Installing Ubuntu system packages..."
sudo apt update
sudo apt install -y \
  git git-lfs curl wget build-essential python3-dev python3-venv python3-pip \
  ffmpeg libsm6 libxext6 libasound-dev portaudio19-dev libportaudio2 libportaudiocpp0 \
  iputils-ping espeak libxkbcommon-x11-0

echo "[2/8] Cloning or updating Stretch AI..."
if [ ! -d "$REPO_DIR/.git" ]; then
  git clone https://github.com/hello-robot/stretch_ai.git --recursive "$REPO_DIR"
else
  cd "$REPO_DIR"
  git pull
  git submodule update --init --recursive
fi

cd "$REPO_DIR"

echo "[3/8] Creating Python venv..."
python3 -m venv venv
source "$REPO_DIR/venv/bin/activate"

echo "[4/8] Upgrading pip tools..."
python -m pip install --upgrade pip setuptools wheel

echo "[5/8] Installing PyTorch CUDA 11.8 wheels..."
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118

echo "[6/8] Installing Stretch AI editable package from src with dev extras..."
cd "$REPO_DIR/src"
pip install -e ".[dev]"

echo "[7/8] Installing pinned runtime requirements..."
pip install -r "$REQ_FILE"

echo "[7.5/8] Applying cmeel-boost compatibility override..."
pip install cmeel-boost==1.89.0 --no-deps

echo "[7.6/8] Applying rerun theta scalar patch if needed..."
python - <<'PY'
from pathlib import Path

p = Path.home() / "stretch_ai/src/stretch/visualization/rerun.py"
if p.exists():
    s = p.read_text()
    s2 = s
    s2 = s2.replace(
        "radians=float(theta),",
        "radians=float(theta.item() if hasattr(theta, 'item') else theta),",
    )
    s2 = s2.replace(
        "radians=theta,",
        "radians=float(theta.item() if hasattr(theta, 'item') else theta),",
    )
    if s2 != s:
        p.write_text(s2)
        print(f"Patched: {p}")
    else:
        print(f"No rerun theta patch needed: {p}")
else:
    print(f"Skipped rerun patch; file not found: {p}")
PY

echo "[8/8] Smoke test imports..."
cd "$REPO_DIR"
python - <<'PY'
import numpy
import torch
import rerun
import cv2
import transformers
import stretch
print("OK: WSL Stretch AI venv imports passed.")
print("numpy:", numpy.__version__)
print("torch:", torch.__version__, "cuda:", torch.cuda.is_available())
print("opencv:", cv2.__version__)
print("transformers:", transformers.__version__)
PY

echo
echo "Done."
echo "Activate later with:"
echo "  source ~/stretch_ai/venv/bin/activate"
echo
echo "Test grasp command:"
echo "  cd ~/stretch_ai/src"
echo "  python -m stretch.app.grasp_object --target_object \"pink bottle\" --robot_ip 172.22.243.38"
