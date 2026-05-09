#!/usr/bin/env python3
"""Bluetooth + WiFi provisioning example over serial shell."""

from __future__ import annotations

import argparse
import shlex
import sys
from typing import List, Tuple

from serial_core import (
    SerialSession,
    auto_select_serial_port,
    make_serial_config,
)


def _run(sess: SerialSession, cmd: str, max_wait: float = 8.0) -> str:
    print(f"\n$ {cmd}")
    out = sess.run_command(cmd, wait_quiet_sec=0.5, max_wait_sec=max_wait)
    if out.strip():
        print(out.rstrip())
    return out


def _step_check_deps(sess: SerialSession) -> None:
    _run(
        sess,
        "which iw wpa_passphrase wpa_supplicant udhcpc bluetoothctl bluetoothd hciconfig",
        max_wait=5.0,
    )


def _step_wifi(sess: SerialSession, ssid: str, password: str, iface: str, ping_host: str) -> None:
    ssid_q = shlex.quote(ssid)
    pass_q = shlex.quote(password)
    iface_q = shlex.quote(iface)
    ping_q = shlex.quote(ping_host)

    _run(sess, f"ip link set {iface_q} up || true", max_wait=3.0)
    _run(sess, f"iw dev {iface_q} scan | grep SSID | head -n 20", max_wait=10.0)
    _run(sess, f"wpa_passphrase {ssid_q} {pass_q} > /etc/wpa_supplicant.conf", max_wait=3.0)
    _run(sess, f"wpa_supplicant -B -Dnl80211 -i{iface_q} -c/etc/wpa_supplicant.conf || true", max_wait=5.0)
    _run(sess, f"udhcpc -i {iface_q} -n -q", max_wait=15.0)
    _run(sess, f"ip -4 addr show {iface_q}", max_wait=5.0)
    _run(sess, f"ping -I {iface_q} -c 2 {ping_q} || true", max_wait=8.0)


def _build_bt_script(mac: str, trust: bool, connect: bool) -> str:
    lines: List[str] = [
        "power on",
        "agent on",
        "default-agent",
        "discoverable on",
        f"pair {mac}",
    ]
    if trust:
        lines.append(f"trust {mac}")
    if connect:
        lines.append(f"connect {mac}")
    lines.append("exit")
    return "\\n".join(lines) + "\\n"


def _step_bt(sess: SerialSession, mac: str, scan_sec: int, trust: bool, connect: bool) -> None:
    mac_q = shlex.quote(mac)
    bt_script = _build_bt_script(mac, trust=trust, connect=connect)
    bt_script_q = shlex.quote(bt_script)

    _run(sess, "bluetoothd >/tmp/bluetoothd.log 2>&1 &", max_wait=2.0)
    _run(sess, "hciconfig -a", max_wait=5.0)
    _run(sess, f"timeout {scan_sec} bluetoothctl scan on || true", max_wait=float(scan_sec + 3))
    _run(sess, f"printf {bt_script_q} | bluetoothctl", max_wait=25.0)
    _run(sess, f"bluetoothctl info {mac_q} || true", max_wait=6.0)


def main() -> int:
    parser = argparse.ArgumentParser(description="WiFi + Bluetooth provisioning over serial")
    parser.add_argument("--port", default="", help="serial port, e.g. /dev/ttyACM0")
    parser.add_argument("--auto-select", action="store_true", help="auto select serial port")
    parser.add_argument("--vid", default="", help="filter VID for auto-select, e.g. 1a86")
    parser.add_argument("--pid", default="", help="filter PID for auto-select, e.g. 55d4")
    parser.add_argument("--baudrate", type=int, default=115200, help="serial baudrate")
    parser.add_argument("--wifi-iface", default="wlan0", help="wifi interface")
    parser.add_argument("--ssid", required=True, help="target wifi SSID")
    parser.add_argument("--password", required=True, help="target wifi password")
    parser.add_argument("--ping-host", default="www.baidu.com", help="host for connectivity check")
    parser.add_argument("--bt-mac", default="", help="bluetooth device MAC to pair")
    parser.add_argument("--bt-scan-sec", type=int, default=10, help="bluetooth scan seconds")
    parser.add_argument("--no-bt-trust", action="store_true", help="skip bluetooth trust")
    parser.add_argument("--no-bt-connect", action="store_true", help="skip bluetooth connect")

    args = parser.parse_args()

    if args.auto_select:
        port = auto_select_serial_port(vid=args.vid, pid=args.pid)
    else:
        port = args.port.strip()
        if not port:
            raise ValueError("请通过 --port 指定串口，或使用 --auto-select")

    cfg = make_serial_config(port=port, baudrate=args.baudrate)
    sess = SerialSession(cfg)
    sess.open()
    print(f"[serial] connected: {port}@{args.baudrate}")

    try:
        _run(sess, "", max_wait=1.0)
        _step_check_deps(sess)
        _step_wifi(
            sess,
            ssid=args.ssid,
            password=args.password,
            iface=args.wifi_iface,
            ping_host=args.ping_host,
        )
        if args.bt_mac:
            _step_bt(
                sess,
                mac=args.bt_mac,
                scan_sec=args.bt_scan_sec,
                trust=not args.no_bt_trust,
                connect=not args.no_bt_connect,
            )
        else:
            print("\n[info] 未传 --bt-mac，已跳过蓝牙配对步骤。")
        print("\n[done] 示例执行完成。")
        return 0
    finally:
        sess.close()


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:  # pragma: no cover - cli safety
        print(f"[error] {exc}", file=sys.stderr)
        raise SystemExit(1)
