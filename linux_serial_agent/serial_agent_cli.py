#!/usr/bin/env python3
from __future__ import annotations

import argparse
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from linux_serial_agent.serial_agent.login_check import run_login_check
from linux_serial_agent.serial_agent.uboot import run_uboot_command


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Serial module abstract interface")
    sub = parser.add_subparsers(dest="subcmd", required=True)

    login = sub.add_parser("login-check", help="Login shell and run a verification command")
    login.add_argument("--serial-agent-dir", default=str(Path(__file__).resolve().parent))
    login.add_argument("--port", default="")
    login.add_argument("--baudrate", type=int, default=115200)
    login.add_argument("--username", default="")
    login.add_argument("--password", default="")
    login.add_argument("--cmd", default="uname -a")
    login.add_argument("--wait-sec", type=int, default=120)
    login.add_argument("--attempt-interval-sec", type=float, default=2.0)

    for name, default_cmd in (("enter-fastboot", "fastboot 0"), ("enter-usb-sdp", "bmode usb"), ("uboot-command", ""), ("reboot", "reset")):
        p = sub.add_parser(name, help=f"Run U-Boot command: {default_cmd or 'custom'}")
        p.add_argument("--port", default="")
        p.add_argument("--baudrate", type=int, default=115200)
        p.add_argument("--wait-sec", type=int, default=120)
        p.add_argument("--attempt-interval-sec", type=float, default=2.0)
        p.add_argument("--login-user", default="root")
        p.add_argument("--login-password", default="")
        if name == "uboot-command":
            p.add_argument("--command", required=True)
        else:
            p.set_defaults(command=default_cmd)

    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    if args.subcmd == "login-check":
        return run_login_check(
            serial_agent_dir=args.serial_agent_dir,
            port=args.port,
            baudrate=args.baudrate,
            username=args.username,
            password=args.password,
            cmd=args.cmd,
            wait_sec=args.wait_sec,
            attempt_interval_sec=args.attempt_interval_sec,
        )
    return run_uboot_command(
        port=args.port,
        baudrate=args.baudrate,
        command=args.command,
        wait_sec=args.wait_sec,
        attempt_interval_sec=args.attempt_interval_sec,
        login_user=args.login_user,
        login_password=args.login_password,
    )


if __name__ == "__main__":
    raise SystemExit(main())
