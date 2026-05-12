from __future__ import annotations

import os
import subprocess
import sys
import time
from pathlib import Path

from linux_serial_agent.serial_agent.discovery import resolve_port


def _default_serial_agent_dir() -> str:
    return str(Path(__file__).resolve().parents[1])


def _go_binary(serial_agent_dir: str) -> str:
    return os.path.join(serial_agent_dir, "trae_serial_terminal_go")


def run_non_login(
    serial_agent_dir: str,
    port: str,
    baudrate: int,
    cmd: str,
    wait_sec: int,
    attempt_interval_sec: float,
) -> int:
    deadline = time.monotonic() + wait_sec
    last_error = "serial command did not succeed"
    go_bin = _go_binary(serial_agent_dir)

    while True:
        try:
            active_port = resolve_port(port)
            print(f"[serial-check] selected port: {active_port}")
            args = [
                go_bin,
                "io",
                "--port",
                active_port,
                "--baudrate",
                str(baudrate),
                "--max-wait-sec",
                "5",
                "--send",
                cmd,
            ]
            result = subprocess.run(args, text=True, capture_output=True)
            if result.stdout:
                print(result.stdout, end="")
            if result.stderr:
                print(result.stderr, end="", file=sys.stderr)
            if result.returncode == 0:
                return 0
            last_error = f"io exit code {result.returncode}"
        except RuntimeError as exc:
            last_error = str(exc)

        if time.monotonic() >= deadline:
            print(f"ERROR: {last_error}", file=sys.stderr)
            return 1
        time.sleep(attempt_interval_sec)


def run_login(
    serial_agent_dir: str,
    port: str,
    baudrate: int,
    user: str,
    password: str,
    cmd: str,
    wait_sec: int,
    attempt_interval_sec: float,
) -> int:
    try:
        import pexpect
    except Exception:
        print("ERROR: pexpect not installed, run: pip install pexpect", file=sys.stderr)
        return 2

    if not os.path.exists("/usr/bin/picocom"):
        print("ERROR: picocom not installed, run: sudo apt-get install -y picocom", file=sys.stderr)
        return 2

    from linux_serial_agent.serial_pexpect import PexpectSerialTerminal

    deadline = time.monotonic() + wait_sec
    last_error = "serial login timed out"

    while True:
        term = None
        try:
            active_port = resolve_port(port)
            print(f"[serial-check] selected port: {active_port}")
            term = PexpectSerialTerminal(port=active_port, baudrate=baudrate, timeout=30)
            term.open()
            term.login(user, password)
            output = term.run(cmd)
            print(output)
            return 0
        except (pexpect.TIMEOUT, pexpect.EOF, OSError, RuntimeError) as exc:
            last_error = str(exc)
        finally:
            if term is not None:
                term.close()

        if time.monotonic() >= deadline:
            print(f"ERROR: {last_error}", file=sys.stderr)
            return 1
        time.sleep(attempt_interval_sec)


def run_login_check(
    serial_agent_dir: str | None = None,
    port: str = "",
    baudrate: int = 115200,
    username: str = "",
    password: str = "",
    cmd: str = "uname -a",
    wait_sec: int = 120,
    attempt_interval_sec: float = 2.0,
) -> int:
    active_dir = serial_agent_dir or _default_serial_agent_dir()
    if username:
        return run_login(
            serial_agent_dir=active_dir,
            port=port,
            baudrate=baudrate,
            user=username,
            password=password,
            cmd=cmd,
            wait_sec=wait_sec,
            attempt_interval_sec=attempt_interval_sec,
        )
    return run_non_login(
        serial_agent_dir=active_dir,
        port=port,
        baudrate=baudrate,
        cmd=cmd,
        wait_sec=wait_sec,
        attempt_interval_sec=attempt_interval_sec,
    )
