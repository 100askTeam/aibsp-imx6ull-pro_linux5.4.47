from __future__ import annotations

import subprocess
import sys
import time
from pathlib import Path
from typing import Optional


def list_usb_devices(uuu_bin: str) -> str:
    result = subprocess.run([uuu_bin, '-lsusb'], text=True, capture_output=True)
    output = result.stdout + result.stderr
    return output.strip()


def detect_usb_mode(uuu_bin: str) -> str:
    output = list_usb_devices(uuu_bin)
    if 'FB:' in output:
        return 'fb'
    if 'SDP:' in output or 'SDPS:' in output or 'SDPU:' in output or 'SDPV:' in output:
        return 'sdp'
    return 'none'


def wait_for_device(uuu_bin: str, mode: str, wait_sec: int) -> str:
    deadline = None if wait_sec == 0 else time.monotonic() + wait_sec
    while True:
        current = detect_usb_mode(uuu_bin)
        if mode == 'any' and current != 'none':
            return current
        if current == mode:
            return current
        if deadline is not None and time.monotonic() >= deadline:
            raise TimeoutError(f'timeout waiting for usb mode {mode}')
        time.sleep(1)


def _stream_command(args: list[str], cwd: Optional[str] = None) -> tuple[int, str]:
    proc = subprocess.Popen(
        args,
        cwd=cwd,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,
    )
    lines = []
    assert proc.stdout is not None
    for line in proc.stdout:
        sys.stdout.write(line)
        sys.stdout.flush()
        lines.append(line)
    proc.wait()
    return proc.returncode, ''.join(lines)


def _normalize_uuu_result(exit_code: int, log_text: str, allow_reset_disconnect: bool) -> int:
    if exit_code == 0:
        return 0
    if allow_reset_disconnect and 'Start Cmd:FB: ucmd reset' in log_text and 'LIBUSB_ERROR_NO_DEVICE' in log_text:
        return 0
    return exit_code


def run_uuu_script(uuu_bin: str, script: str, cwd: Optional[str] = None, allow_reset_disconnect: bool = False) -> int:
    exit_code, log_text = _stream_command([uuu_bin, '-v', script], cwd=cwd)
    return _normalize_uuu_result(exit_code, log_text, allow_reset_disconnect)


def flash_emmc_all(uuu_bin: str, flash_bin: str, emmc_img: str) -> int:
    exit_code, _ = _stream_command([uuu_bin, '-v', '-b', 'emmc_all', flash_bin, emmc_img])
    return exit_code


def write_fastboot_script(output_path: str, image_name: str = 'sdcard.img', reset: bool = True) -> str:
    lines = [
        'uuu_version 1.4.193',
        'FB: ucmd setenv fastboot_dev mmc',
        'FB: ucmd mmc dev 1',
        f'FB: flash -raw2sparse all {image_name}',
    ]
    if reset:
        lines.append('FB: ucmd reset')
    lines.append('FB: done')
    path = Path(output_path)
    path.write_text('\n'.join(lines) + '\n', encoding='ascii')
    return str(path)
