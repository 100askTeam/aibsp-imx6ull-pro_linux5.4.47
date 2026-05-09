#!/usr/bin/env python3
import argparse
import json
import os
import subprocess
import sys


def pick_port(serial_agent_dir: str) -> str:
    go_bin = os.path.join(serial_agent_dir, "trae_serial_terminal_go")
    out = subprocess.check_output([go_bin, "scan", "--json"], text=True)
    ports = json.loads(out)
    preferred = []
    fallback = []
    for p in ports:
        dev = p.get("device", "")
        if dev.startswith("/dev/ttyUSB") or dev.startswith("/dev/ttyACM"):
            preferred.append(dev)
        elif dev.startswith("/dev/tty"):
            fallback.append(dev)
    if preferred:
        return preferred[0]
    if fallback:
        return fallback[0]
    raise RuntimeError("no serial port found")


def run_non_login(go_bin: str, port: str, baudrate: int, cmd: str) -> int:
    args = [
        go_bin,
        "io",
        "--port",
        port,
        "--baudrate",
        str(baudrate),
        "--max-wait-sec",
        "5",
        "--send",
        cmd,
    ]
    return subprocess.call(args)


def run_login(serial_agent_dir: str, port: str, baudrate: int, user: str, password: str, cmd: str) -> int:
    try:
        import pexpect  # noqa: F401
    except Exception:
        print("ERROR: pexpect not installed, run: pip install pexpect", file=sys.stderr)
        return 2

    if not os.path.exists("/usr/bin/picocom"):
        print("ERROR: picocom not installed, run: sudo apt-get install -y picocom", file=sys.stderr)
        return 2

    sys.path.insert(0, serial_agent_dir)
    from serial_pexpect import PexpectSerialTerminal  # type: ignore

    term = PexpectSerialTerminal(port=port, baudrate=baudrate, timeout=30)
    try:
        term.open()
        term.login(user, password)
        output = term.run(cmd)
        print(output)
        return 0
    finally:
        term.close()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--serial-agent-dir", required=True)
    parser.add_argument("--port", default="")
    parser.add_argument("--baudrate", type=int, default=115200)
    parser.add_argument("--username", default="")
    parser.add_argument("--password", default="")
    parser.add_argument("--cmd", default="uname -a")
    args = parser.parse_args()

    port = args.port or pick_port(args.serial_agent_dir)
    print(f"[serial-check] selected port: {port}")

    go_bin = os.path.join(args.serial_agent_dir, "trae_serial_terminal_go")
    if args.username:
        return run_login(
            serial_agent_dir=args.serial_agent_dir,
            port=port,
            baudrate=args.baudrate,
            user=args.username,
            password=args.password,
            cmd=args.cmd,
        )
    return run_non_login(go_bin=go_bin, port=port, baudrate=args.baudrate, cmd=args.cmd)


if __name__ == "__main__":
    raise SystemExit(main())
