#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Stretch AI WSL Environment Setup Script
#
# Purpose:
# This script builds the local WSL runtime used by the
# Windows voice interaction system (voice_master_v2.py).
#
# Design philosophy:
#
# Instead of running heavy speech interaction and AI logic
# directly on the robot, the project separates computation:
#
# Windows
#   -> microphone input
#   -> Whisper speech transcription
#   -> LLM intent parsing
#
# WSL Ubuntu
#   -> Stretch AI client logic
#   -> grasp / teleoperation commands
#
# Stretch Robot
#   -> ROS2 bridge and physical execution
#
# This architecture keeps the robot lightweight and reduces
# installation complexity on the robot itself.
#
# Expected final structure:
#
#   ~/stretch_ai
#   ~/stretch_ai/venv
#
# IMPORTANT:
#
# This script only builds the runtime environment.
#
# The customized project behavior is implemented separately.
#
# After setup, manually replace:
#
#   ~/stretch_ai/task2_client.py
#   ~/stretch_ai/src/stretch/perception/encoders/siglip_encoder.py
#   ~/stretch_ai/src/stretch/app/grasp_object.py
#   ~/stretch_ai/src/stretch/agent/robot_agent_dynamem.py
#
# Reason:
#
# The original StretchAI repository provides the baseline
# framework only.
#
# Project-specific behavior was implemented by modifying
# several files during development.
#
# Separating environment setup from behavioral customization
# makes future updates easier and avoids editing installation
# scripts repeatedly.
# ============================================================


REPO_DIR="$HOME/stretch_ai"

# Directory containing this script
#
# This allows requirement files to remain relative to the
# script location rather than relying on absolute paths.
#
# Avoids:
#
# /home/username/...
#
# which often causes reproducibility issues across users.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"



# Requirement file with pinned versions
#
# Package versions changed frequently during debugging.
#
# Final versions were pinned after resolving dependency
# conflicts and runtime issues.

REQ_FILE="$SCRIPT_DIR/wsl_venv_requirements.txt"



echo "[1/8] Installing Ubuntu system packages..."


# ------------------------------------------------------------
# Install Ubuntu dependencies
#
# Categories:
#
# git:
#     repository + submodules
#
# audio:
#     microphone and speech libraries
#
# ffmpeg:
#     media processing
#
# python:
#     venv and package support
#
# visualization:
#     OpenCV / GUI dependencies
#
# Some packages may appear unrelated to the final workflow
# but were included to avoid common runtime failures seen
# during earlier deployment attempts.
# ------------------------------------------------------------

sudo apt update

sudo apt install -y \
  git git-lfs curl wget build-essential python3-dev python3-venv python3-pip \
  ffmpeg libsm6 libxext6 \
  libasound-dev portaudio19-dev libportaudio2 libportaudiocpp0 \
  iputils-ping espeak libxkbcommon-x11-0



echo "[2/8] Cloning or updating Stretch AI..."


# ------------------------------------------------------------
# Clone repository once
#
# Future runs update instead of recloning.
#
# Recursive clone required because StretchAI relies on
# multiple submodules.
#
# Missing submodules often caused partial installations.
# ------------------------------------------------------------

if [ ! -d "$REPO_DIR/.git" ]; then

  git clone \
  https://github.com/hello-robot/stretch_ai.git \
  --recursive "$REPO_DIR"

else

  cd "$REPO_DIR"

  git pull

  git submodule update --init --recursive

fi



cd "$REPO_DIR"



echo "[3/8] Creating Python venv..."


# ------------------------------------------------------------
# Create isolated environment
#
# Earlier testing showed package conflicts between:
#
# system python
# conda
# StretchAI
#
# Using a dedicated venv minimizes environment drift.
# ------------------------------------------------------------

python3 -m venv venv

source "$REPO_DIR/venv/bin/activate"



echo "[4/8] Upgrading pip tools..."


# Upgrade package tools first
#
# Older pip versions occasionally produced dependency
# resolution issues.

python -m pip install --upgrade pip setuptools wheel



echo "[5/8] Installing PyTorch CUDA..."


# CUDA 11.8 build
#
# Selected because it matched the Windows development setup
# and RTX 3060 testing environment.

pip install torch torchvision torchaudio \
--index-url https://download.pytorch.org/whl/cu118



echo "[6/8] Installing Stretch AI..."


# Editable installation:
#
# allows source modifications to take effect immediately
#
# avoids reinstalling after every code update

cd "$REPO_DIR/src"

pip install -e ".[dev]"



echo "[7/8] Installing runtime requirements..."


# Install final pinned package versions

pip install -r "$REQ_FILE"



echo "[7.5/8] Applying dependency compatibility fix..."


# ------------------------------------------------------------
# Compatibility patch
#
# Certain package combinations generated runtime issues.
#
# Earlier testing showed cmeel-boost version mismatches.
#
# Fixed version retained for reproducibility.
# ------------------------------------------------------------

pip install cmeel-boost==1.89.0 --no-deps



echo "[7.6/8] Applying rerun patch..."


# ------------------------------------------------------------
# Visualization patch
#
# Earlier Rerun visualization occasionally failed when
# theta values arrived as tensors instead of scalars.
#
# Patch converts tensor-like values safely.
#
# This issue does not always appear but keeping the patch
# avoids repeated debugging later.
# ------------------------------------------------------------

python - <<'PY'
...
PY



echo "[8/8] Smoke testing..."


# ------------------------------------------------------------
# Final validation
#
# Import test verifies:
#
# numpy
# torch
# rerun
# opencv
# transformers
# StretchAI
#
# Goal:
#
# detect environment failures immediately rather than during
# robot execution.
# ------------------------------------------------------------

python - <<'PY'
...
PY



echo
echo "Setup finished."
echo

echo "Next step:"
echo "source ~/stretch_ai/venv/bin/activate"

echo
echo "Smoke test:"

echo "cd ~/stretch_ai/src"

echo 'python -m stretch.app.grasp_object --target_object "pink bottle" --robot_ip 172.22.243.38'
