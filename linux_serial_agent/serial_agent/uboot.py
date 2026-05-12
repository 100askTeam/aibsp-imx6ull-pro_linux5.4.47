from __future__ import annotations

import re
import sys
import time

import serial

from linux_serial_agent.serial_agent.discovery import resolve_port

SHELL_PROMPT_RE = re.compile(r"[#\$] $", re.M)


def _write_bytes(ser: serial.Serial, payload: bytes) -> None:
    ser.write(payload)
    ser.flush()


def _write_line(ser: serial.Serial, text: str) -> None:
    _write_bytes(ser, text.encode() + b"\r")


def _attempt_uboot_command(
    port: str,
    baudrate: int,
    command: str,
    wait_sec: int,
    login_user: str,
    login_password: str,
) -> tuple[bool, str]:
    active_port = resolve_port(port)
    print(f"[serial-uboot] selected port: {active_port}")
    ser = serial.Serial(active_port, baudrate, timeout=0.15, write_timeout=1)
    buf = ""
    sent_user = False
    sent_pass = False
    sent_reboot = False
    sent_space = False
    try:
        for payload in (b"\n", b"\x03\x03\n", b"reboot\n"):
            _write_bytes(ser, payload)
            time.sleep(0.2)
        deadline = time.monotonic() + wait_sec
        while time.monotonic() < deadline:
            chunk = ser.read(4096)
            if chunk:
                text = chunk.decode(errors="ignore")
                buf = (buf + text)[-50000:]

                if "Hit any key to stop autoboot" in buf and not sent_space:
                    _write_bytes(ser, b" ")
                    sent_space = True
                    time.sleep(0.1)
                    continue

                if "=> " in buf:
                    _write_bytes(ser, b"\x03\x03\r")
                    time.sleep(0.1)
                    if command:
                        _write_line(ser, command)
                        time.sleep(0.2)
                        tail = ser.read(4096)
                        if tail:
                            buf = (buf + tail.decode(errors="ignore"))[-50000:]
                    return True, buf

                if "login:" in buf and login_user and not sent_user:
                    _write_line(ser, login_user)
                    sent_user = True
                    time.sleep(0.1)
                    continue

                if "Password:" in buf and not sent_pass:
                    _write_line(ser, login_password)
                    sent_pass = True
                    time.sleep(0.1)
                    continue

                if SHELL_PROMPT_RE.search(buf) and not sent_reboot:
                    _write_line(ser, "reboot")
                    sent_reboot = True
                    time.sleep(0.2)
                    continue
            time.sleep(0.02)
        return False, buf
    finally:
        ser.close()


def run_uboot_command(
    port: str = "",
    baudrate: int = 115200,
    command: str = "",
    wait_sec: int = 120,
    attempt_interval_sec: float = 2.0,
    login_user: str = "root",
    login_password: str = "",
) -> int:
    deadline = time.monotonic() + wait_sec
    last_capture = ""
    while True:
        try:
            ok, capture = _attempt_uboot_command(
                port=port,
                baudrate=baudrate,
                command=command,
                wait_sec=min(wait_sec, 90),
                login_user=login_user,
                login_password=login_password,
            )
            last_capture = capture
            if capture:
                print(capture)
            if ok:
                return 0
        except (RuntimeError, OSError, serial.SerialException) as exc:
            last_capture = str(exc)

        if time.monotonic() >= deadline:
            if last_capture:
                print(last_capture, file=sys.stderr)
            print("ERROR: failed to reach U-Boot prompt", file=sys.stderr)
            return 1
        time.sleep(attempt_interval_sec)
