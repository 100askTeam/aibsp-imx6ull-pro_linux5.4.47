from __future__ import annotations

import os
import re
import sys
import time
from pathlib import Path

import serial

from linux_serial_agent.serial_agent.discovery import resolve_port


def _default_serial_agent_dir() -> str:
    return str(Path(__file__).resolve().parents[1])


SHELL_PROMPT_RE = re.compile(r"[#\$] $", re.M)


def _write_line(ser: serial.Serial, text: str) -> None:
    ser.write(text.encode() + b"\r")
    ser.flush()


def _log_action(message: str) -> None:
    print(f"[serial-check] {message}")


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

    while True:
        ser = None
        try:
            active_port = resolve_port(port)
            _log_action(f"selected port: {active_port}")
            ser = serial.Serial(active_port, baudrate, timeout=0.2, write_timeout=1)
            buf = ""
            sent_user = False
            sent_cmd = False
            next_ping = 0.0
            while time.monotonic() < deadline:
                now = time.monotonic()
                if now >= next_ping:
                    _log_action("send <CR>")
                    _write_line(ser, "")
                    next_ping = now + 3.0
                data = ser.read(4096)
                if data:
                    text = data.decode(errors="ignore")
                    print(text, end="")
                    buf = (buf + text)[-50000:]
                    if "login:" in buf and not sent_user:
                        _log_action("detected login prompt -> send root")
                        _write_line(ser, "root")
                        sent_user = True
                        buf = ""
                        next_ping = time.monotonic() + 1.0
                        continue
                    if SHELL_PROMPT_RE.search(buf) and not sent_cmd:
                        _log_action(f"detected shell prompt -> send command: {cmd}")
                        _write_line(ser, cmd)
                        sent_cmd = True
                        buf = ""
                        next_ping = time.monotonic() + 1.0
                        continue
                    if sent_cmd and SHELL_PROMPT_RE.search(buf):
                        return 0
                time.sleep(0.05)
            last_error = "timed out waiting for login prompt or command output"
        except (RuntimeError, OSError, serial.SerialException) as exc:
            last_error = str(exc)
        finally:
            if ser is not None:
                ser.close()

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
