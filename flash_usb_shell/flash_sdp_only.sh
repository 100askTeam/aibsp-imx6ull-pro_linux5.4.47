#!/usr/bin/env bash
set -euo pipefail

WORK_DIR="${WORK_DIR:-/home/ubuntu/imx6ull-pro_linux5.4.47}"
UUU_BIN="${UUU_BIN:-$WORK_DIR/uuucli/build/uuu/uuu}"
FLASH_BIN="${FLASH_BIN:-$WORK_DIR/buildroot-2026.02.1/output/images/u-boot-dtb.imx}"
EMMC_IMG="${EMMC_IMG:-$WORK_DIR/buildroot-2026.02.1/output/images/sdcard.img}"
WAIT_SDP_SEC="${WAIT_SDP_SEC:-0}"

log() { echo "[sdp-usb] $*"; }
die() { echo "[sdp-usb][ERROR] $*" >&2; exit 1; }
need_file() { [[ -f "$1" ]] || die "missing file: $1"; }

main() {
  need_file "$WORK_DIR/flash_usb_shell/usb_flash_cli.py"
  need_file "$FLASH_BIN"
  need_file "$EMMC_IMG"
  log "wait for sdp USB device"
  sudo python3 "$WORK_DIR/flash_usb_shell/usb_flash_cli.py" --uuu-bin "$UUU_BIN" wait-device --mode sdp --wait-sec "$WAIT_SDP_SEC"
  log "start sdp emmc_all flashing"
  sudo python3 "$WORK_DIR/flash_usb_shell/usb_flash_cli.py" --uuu-bin "$UUU_BIN" emmc-all \
    --flash-bin "$FLASH_BIN" \
    --emmc-img "$EMMC_IMG"
}

main "$@"
