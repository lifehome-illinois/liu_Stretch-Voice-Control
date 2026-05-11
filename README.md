# Stretch Voice Control Setup

## 1. Robot Side

SSH into Stretch:

```bash
ssh hello-robot@172.22.243.38
```

Password:

```text
hello2020
```

Enter Stretch AI:

```bash
cd ~/stretch_ai
conda activate stretch_ai_cpu_0.3.3
```

Start the robot bridge:

```bash
stretch_free_robot_process.py
stretch_robot_home.py
./scripts/run_stretch_ai_ros2_bridge_server.sh
```

Keep this terminal running.

## 2. WSL Ubuntu 22.04 Side

Copy these two files into WSL, preferably in the same folder:

```text
setup_wsl_venv.sh
wsl_venv_requirements.txt
```

Run:

```bash
chmod +x setup_wsl_venv.sh
./setup_wsl_venv.sh
```

This creates:

```text
~/stretch_ai
~/stretch_ai/venv
```

After setup, manually replace:

```text
~/stretch_ai/task2_client.py
~/stretch_ai/src/stretch/perception/encoders/siglip_encoder.py
~/stretch_ai/src/stretch/app/grasp_object.py
~/stretch_ai/src/stretch/agent/robot_agent_dynamem.py
```

Test from WSL:

```bash
source ~/stretch_ai/venv/bin/activate
cd ~/stretch_ai/src
python -m stretch.app.grasp_object --target_object "pink bottle" --robot_ip 172.22.243.38
```

## 3. Windows Side

Create the Conda environment:

```powershell
conda create -n stretch_brain python=3.10 -y
conda activate stretch_brain
```

Install Conda packages:

```powershell
conda install -c conda-forge ffmpeg portaudio pyaudio -y
```

Install PyTorch with CUDA 11.8:

```powershell
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118
```

Install Python packages:

```powershell
pip install -r stretch_brain_requirements.txt
```

Set a valid OpenRouter API key before running. Do not use the old hardcoded key.

Run the voice controller:

```powershell
conda activate stretch_brain
python voice_master_v2.py
```

Use Administrator PowerShell or Administrator Anaconda Prompt if keyboard hotkeys do not work.

## 4. Runtime Flow

```text
Windows voice_master_v2.py
        ↓
WSL Ubuntu ~/stretch_ai/venv
        ↓
Stretch AI client code
        ↓
Robot bridge at 172.22.243.38
        ↓
Stretch robot execution
```

## 5. Removed From the Final WSL Setup

The final WSL setup removes unrelated or broken commands:

```text
conda tos accept ...
conda create -n stretch_brain ...
conda install pyaudio ...
wsl -u root / passwd ...
pip install ... -y
manual /home/shafiqul/... absolute path edits
duplicate uninstall/reinstall loops
broken smart quote in "tifffile<2024.1.0”
```
