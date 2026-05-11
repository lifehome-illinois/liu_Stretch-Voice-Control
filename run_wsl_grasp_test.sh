#!/usr/bin/env bash
set -euo pipefail

source "$HOME/stretch_ai/venv/bin/activate"
cd "$HOME/stretch_ai/src"

python -m stretch.app.grasp_object \
  --target_object "pink bottle" \
  --robot_ip 172.22.243.38
