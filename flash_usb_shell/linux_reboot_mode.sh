#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-}"

if [[ -z "${MODE}" ]]; then
  echo "Usage: $0 {usb_sdp|recovery|normal}" >&2
  exit 2
fi

if ! command -v fw_setenv >/dev/null 2>&1; then
  echo "ERROR: fw_setenv not found. install: sudo apt-get install -y u-boot-tools" >&2
  exit 2
fi

case "${MODE}" in
  usb_sdp)
    sudo fw_setenv reboot_mode usb_sdp
    ;;
  recovery)
    sudo fw_setenv reboot_mode recovery
    ;;
  normal)
    sudo fw_setenv reboot_mode
    ;;
  *)
    echo "ERROR: invalid mode: ${MODE}" >&2
    exit 2
    ;;
esac

sync
echo "[linux-reboot-mode] reboot_mode=${MODE}, rebooting..."
sudo reboot
