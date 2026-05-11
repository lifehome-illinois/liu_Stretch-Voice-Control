#!/usr/bin/env python3
import argparse
import math
import time
import sys


import rerun as rr
rr.init("stretch_teleop", spawn=False)  # 提前静默初始化，满足官方的内部依赖
rr.spawn = lambda *args, **kwargs: print("[System] Rerun UI popup suppressed by Monkeypatch.")
rr.serve = lambda *args, **kwargs: None

from stretch.agent.zmq_client import HomeRobotZmqClient

def main():
    parser = argparse.ArgumentParser(description="ZMQ Client for Stretch Voice Teleoperation")
    parser.add_argument('--action', type=str, required=True, help="Action to perform (forward, back, left, right)")
    parser.add_argument('--val', type=float, default=0.1, help="Value for distance (meters) or rotation (degrees)")
    parser.add_argument('--robot_ip', type=str, default="172.22.243.38", help="IP address of the robot")
    args = parser.parse_args()

    print(f"[ZMQ Client] Connecting to Bridge Server at {args.robot_ip}...")
    
    robot = None
    try:
        
        robot = HomeRobotZmqClient(robot_ip=args.robot_ip)
        robot.start()
        
        
        time.sleep(0.5)

        if args.action in ['forward', 'back', 'left', 'right']:
            robot.switch_to_navigation_mode()
            
            dx, dy, dtheta = 0.0, 0.0, 0.0
            
            if args.action == 'forward':
                dx = args.val
            elif args.action == 'back':
                dx = -args.val
            elif args.action == 'left':
                dtheta = args.val * (math.pi / 180.0)
            elif args.action == 'right':
                dtheta = -args.val * (math.pi / 180.0)

            print(f"[ZMQ Client] Sending relative base command -> dx: {dx}m, dtheta: {dtheta}rad")
            
           
            robot.move_base_to([dx, dy, dtheta], relative=True, blocking=False)
            
            
            move_duration = 2.0
            print(f"[ZMQ Client] Waiting {move_duration}s for physical execution...")
            time.sleep(move_duration)
            
            print("[ZMQ Client] Base movement executed successfully.")

        elif args.action in ['extend', 'retract']:
            print("[ZMQ Client] Arm manipulation placeholder. Currently focusing on base navigation.")

    except Exception as e:
        print(f"[ZMQ Client] Error executing command: {e}")
        sys.exit(1)
        
    finally:
    
        print("[ZMQ Client] Closing connection.")
        if robot is not None:
            try:
                robot.stop()
            except:
                pass

if __name__ == '__main__':
    main()
