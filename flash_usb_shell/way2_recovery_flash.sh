#!/usr/bin/env bash
set -euo pipefail

WORK_DIR="${WORK_DIR:-/home/ubuntu/imx6ull-pro_linux5.4.47}"
UUU_BIN="${UUU_BIN:-$WORK_DIR/uuucli/build/uuu/uuu}"
IMAGES_DIR="${IMAGES_DIR:-$WORK_DIR/buildroot-2026.02.1/output/images}"
UUU_SCRIPT="${UUU_SCRIPT:-$WORK_DIR/flash_usb_shell/recovery_fastboot_flash.uuu}"

if [[ ! -x "$UUU_BIN" ]]; then
  echo "[way2] missing uuu: $UUU_BIN" >&2
  exit 2
fi
if [[ ! -d "$IMAGES_DIR" ]]; then
  echo "[way2] missing images dir: $IMAGES_DIR" >&2
  exit 2
fi
if [[ ! -f "$UUU_SCRIPT" ]]; then
  echo "[way2] missing uuu script: $UUU_SCRIPT" >&2
  exit 2
fi

cd "$IMAGES_DIR"
sudo "$UUU_BIN" -v "$UUU_SCRIPT"
