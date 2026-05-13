#!/usr/bin/env bash
set -euo pipefail

WORK_DIR="${WORK_DIR:-/home/ubuntu/imx6ull-pro_linux5.4.47}"
UUU_BIN="${UUU_BIN:-$WORK_DIR/uuucli/build/uuu/uuu}"
IMAGES_DIR="${IMAGES_DIR:-$WORK_DIR/buildroot-2026.02.1/output/images}"
IMAGE_NAME="${IMAGE_NAME:-sdcard.img}"
FASTBOOT_SCRIPT_NAME="${FASTBOOT_SCRIPT_NAME:-flash_from_fb_local.uuu}"

log() { echo "[fastboot-usb] $*"; }
die() { echo "[fastboot-usb][ERROR] $*" >&2; exit 1; }
need_file() { [[ -f "$1" ]] || die "missing file: $1"; }

main() {
  need_file "$WORK_DIR/flash_usb_shell/usb_flash_cli.py"
  need_file "$IMAGES_DIR/$IMAGE_NAME"
  log "generate fastboot uuu script"
  python3 "$WORK_DIR/flash_usb_shell/usb_flash_cli.py" write-fastboot-script \
    --output "$IMAGES_DIR/$FASTBOOT_SCRIPT_NAME" \
    --image-name "$IMAGE_NAME" \
    --no-prepare >/dev/null
  log "wait for fastboot USB device"
  sudo python3 "$WORK_DIR/flash_usb_shell/usb_flash_cli.py" --uuu-bin "$UUU_BIN" wait-device --mode fb --wait-sec 0
  log "start fastboot flashing"
  sudo python3 "$WORK_DIR/flash_usb_shell/usb_flash_cli.py" --uuu-bin "$UUU_BIN" run-script \
    --script "$FASTBOOT_SCRIPT_NAME" \
    --cwd "$IMAGES_DIR" \
    --allow-reset-disconnect
}

main "$@"
