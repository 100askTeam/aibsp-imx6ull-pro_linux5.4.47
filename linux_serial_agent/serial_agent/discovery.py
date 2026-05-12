from __future__ import annotations

import os
from typing import List

from linux_serial_agent.serial_core import list_serial_ports_detail

USB_SERIAL_PREFIXES = ("/dev/ttyACM", "/dev/ttyUSB")


def list_candidate_ports() -> List[str]:
    ports = []
    for item in list_serial_ports_detail():
        dev = item.get("device", "")
        if dev.startswith(USB_SERIAL_PREFIXES):
            ports.append(dev)
    return ports


def resolve_port(requested_port: str = "") -> str:
    if requested_port and os.path.exists(requested_port):
        return requested_port

    ports = list_candidate_ports()
    if requested_port and requested_port in ports:
        return requested_port
    if ports:
        return ports[0]
    raise RuntimeError("no serial port found")
