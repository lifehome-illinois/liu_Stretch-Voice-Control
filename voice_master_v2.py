import os
import sys
import json
import re
import time
import speech_recognition as sr
import keyboard  
from openai import OpenAI

# ==========================================
# 0. Core Configuration: API & WSL Commands
# ==========================================
# ⚠️ Insert your real OpenAI API Key here!
OPENAI_API_KEY = "LIFE Home API" # Replace with your actual key

# WSL execution command for Task 1 (Grasp Object)
TASK1_WSL_CMD = (
    'wsl.exe -d Ubuntu-24.04 bash -c '
    '"cd ~/stretch_ai && '
    'export PATH=~/stretch_ai/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin && '
    'export PYTHONPATH=~/stretch_ai/src && '
    'python3 -m stretch.app.grasp_object --target_object \\"pink bottle\\" --robot_ip 172.22.243.38"'
)

# Whisper prompt to guide the transcription context
WHISPER_PROMPT = "Task one. Task two. Move forward. Move back. Turn left. Turn right. Extend. Retract. Stop. Quit. Exit. grasp that pink bottle."

# ==========================================
# 1. Cloud LLM Initialization (Central Brain)
# ==========================================
# Initialize OpenAI client for both LLM parsing and Cloud Audio Transcription
client = OpenAI(
    api_key=OPENAI_API_KEY, 
)

def parse_voice_intent(user_command: str) -> dict:
    """Use GPT-4o to parse all intents: Task1, Task2, or Teleop movements"""
    system_prompt = (
        "You are the central brain for a robot. Parse the user's voice command and return ONLY a valid JSON.\n"
        "Rules:\n"
        "1. If the user wants to grasp/pick up an object (e.g., 'can u help me grasp that pink bottle', 'grasp task'): return {\"intent\": \"task1\"}\n"
        "2. If the user explicitly asks to start task 2 or teleop mode: return {\"intent\": \"task2\"}\n"
        "3. If the user wants to exit, stop, or quit: return {\"intent\": \"exit\"}\n"
        "4. If the user gives a movement command, return: {\"intent\": \"<direction>\", \"value\": <number>}\n"
        "   - Valid directions: 'forward', 'back', 'left', 'right', 'extend', 'retract'.\n"
        "   - DEFAULT translation (forward/back): 0.3\n"
        "   - DEFAULT rotation (left/right): 45\n"
        "   - If they say 'turn around', return {\"intent\": \"right\", \"value\": 360} or left 360."
    )
    print(f"[Brain] Thinking... '{user_command}'")
    try:
        response = client.chat.completions.create(
            model="gpt-4o-mini",  
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_command}
            ],
            temperature=0.1
        )

        content = response.choices[0].message.content.strip()
        match = re.search(r'\{.*\}', content, re.DOTALL)
        if match:
            return json.loads(match.group(0))
        else:
            raise ValueError("No JSON found.")

    except Exception as e:
        print(f"[Error] LLM parsing failed: {e}")
        return None

# ==========================================
# 2. Execution Module (WSL ZMQ Client)
# ==========================================
def execute_task1():
    print("\n[Trigger] Task 1 activated. Initializing grasp sequence...")
    os.system(TASK1_WSL_CMD)
    print("[Cleanup] Auto-closing Rerun visualization window...")
    os.system('wsl.exe -d Ubuntu-24.04 bash -c "pkill -9 -f rerun"')
    print("[Success] Task 1 execution finished.\n")

def execute_task2_action(intent: str, value: float):
    print(f"\n[Hardware] Executing action: {intent.upper()}, Value: {value}\n")
    cmd = (
        f'wsl.exe -d Ubuntu-24.04 bash -c '
        f'"cd ~/stretch_ai && '
        f'export PATH=~/stretch_ai/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin && '
        f'export PYTHONPATH=~/stretch_ai/src && '
        f'python3 task2_client.py --action {intent} --val {value} --robot_ip 172.22.243.38"'
    )
    os.system(cmd)

# ==========================================
# 3. Auditory & Keyboard Event Loop
# ==========================================
def record_and_transcribe(recognizer, source, phrase_time_limit):
    """Helper function to record audio and transcribe using OpenAI Cloud API"""
    print("🔵 [Listening] Speak now...")
    try:
        # Record audio from the microphone
        audio = recognizer.listen(source, timeout=10, phrase_time_limit=phrase_time_limit)
        
        # Save as standard WAV file (Bypasses the need for local FFmpeg)
        with open("temp.wav", "wb") as f:
            f.write(audio.get_wav_data())

        print("☁️ [System] Uploading to OpenAI for transcription...")
        
        # Call OpenAI's Whisper API for cloud transcription
        with open("temp.wav", "rb") as audio_file:
            transcription = client.audio.transcriptions.create(
                model="whisper-1", 
                file=audio_file,
                prompt=WHISPER_PROMPT
            )
            
        return transcription.text.strip().lower()
        
    except sr.WaitTimeoutError:
        print("[System] No speech detected.")
        return ""
    except Exception as e:
        print(f"[Warning] Audio error: {e}")
        return ""

def main():
    print("\n[System] Initializing System...")
    # Removed local whisper model loading to speed up startup and avoid dependencies
    
    recognizer = sr.Recognizer()

    with sr.Microphone(device_index=0) as source:
        print("\n[System] Calibrating microphone...")
        recognizer.adjust_for_ambient_noise(source, duration=1.0)
        recognizer.dynamic_energy_threshold = False

    print("\n" + "=" * 55)
    print("🤖 Stretch Robot Voice Hub Online! (Push-to-Talk Mode)")
    print("   [SPACE] : Tap to Speak")
    print("   [ 1 ]   : Force Start Task 1 (Grasp Pink Bottle)")
    print("   [ 2 ]   : Force Start Task 2 (Teleop Mode)")
    print("   [ ESC ] : Exit System")
    print("=" * 55 + "\n")

    while True:
        # Reduce CPU usage
        time.sleep(0.05)

        # --- Keyboard Overrides (Noisy Environment Fallback) ---
        if keyboard.is_pressed('1'):
            print("\n[Hotkey] '1' pressed.")
            execute_task1()
            time.sleep(1)  # Debounce
            continue

        elif keyboard.is_pressed('2'):
            print("\n[Hotkey] '2' pressed. Entering Task 2 manually.")
            task2_loop(recognizer) # Removed audio_model parameter
            continue

        elif keyboard.is_pressed('esc'):
            print("\n[Shutdown] Safely terminating system...")
            if os.path.exists("temp.wav"): os.remove("temp.wav")
            sys.exit(0)

        # --- Tap to Talk (Spacebar) ---
        elif keyboard.is_pressed('space'):
            
            # Wait until the user releases the spacebar before listening
            while keyboard.is_pressed('space'): time.sleep(0.01)

            with sr.Microphone(device_index=0) as source:
                text = record_and_transcribe(recognizer, source, phrase_time_limit=8.0)

            if not text: continue
            print(f"🗣️  Recognized: '{text}'")

            decision = parse_voice_intent(text)
            if not decision: continue

            intent = decision.get("intent")

            if intent == "task1":
                execute_task1()
            elif intent == "task2":
                task2_loop(recognizer) # Removed audio_model parameter
            elif intent == "exit":
                print("\n[Shutdown] Exiting program...")
                if os.path.exists("temp.wav"): os.remove("temp.wav")
                sys.exit(0)
            else:
                print(f"[System] Standby. Unrecognized main intent: {decision}")


def task2_loop(recognizer): # Removed audio_model parameter
    print("\n" + "=" * 45)
    print("🕹️  Task 2 Teleop Mode Active!")
    print("   [SPACE] : Voice Command (e.g. 'move forward')")
    print("   [W/S]   : Move Forward/Back (0.5m)")
    print("   [A/D]   : Turn Left/Right (90 deg)")
    print("   [ESC/Q] : Exit Task 2")
    print("=" * 45 + "\n")

    while True:
        time.sleep(0.05)

        # --- WASD Manual Override ---
        if keyboard.is_pressed('w'):
            execute_task2_action("forward", 0.5)
            time.sleep(0.5)  # Movement debounce
        elif keyboard.is_pressed('s'):
            execute_task2_action("back", 0.5)
            time.sleep(0.5)
        elif keyboard.is_pressed('a'):
            execute_task2_action("left", 90.0)
            time.sleep(0.5)
        elif keyboard.is_pressed('d'):
            execute_task2_action("right", 90.0)
            time.sleep(0.5)

        # --- Exit Task 2 ---
        elif keyboard.is_pressed('esc') or keyboard.is_pressed('q'):
            print("\n[Navigation] Exiting Task 2. Returning to main menu.\n")
            time.sleep(0.5)
            break

        # --- Tap to Talk for Movement ---
        elif keyboard.is_pressed('space'):
            # Wait until the user releases the spacebar before listening
            while keyboard.is_pressed('space'): time.sleep(0.01)

            with sr.Microphone(device_index=0) as source:
                text = record_and_transcribe(recognizer, source, phrase_time_limit=6.0)

            if not text: continue
            print(f"🗣️  Teleop Command: '{text}'")

            decision = parse_voice_intent(text)
            if not decision: continue

            intent = decision.get("intent")
            if intent in ["exit", "task1", "task2"]:
                if intent == "exit":
                    print("[Navigation] Exiting Task 2 by voice.")
                    break
                else:
                    print("[System] Please exit Task 2 first to change modes.")
            else:
                value = decision.get("value", 0.3)  # Fallback default value
                execute_task2_action(intent, value)


if __name__ == "__main__":
    main()