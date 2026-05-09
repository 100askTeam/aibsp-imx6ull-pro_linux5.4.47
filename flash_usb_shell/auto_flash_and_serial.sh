#!/usr/bin/env bash
set -euo pipefail

WORK_DIR="${WORK_DIR:-/home/ubuntu/imx6ull-pro_linux5.4.47}"
UUU_BIN="${UUU_BIN:-$WORK_DIR/uuucli/build/uuu/uuu}"
SERIAL_AGENT_DIR="${SERIAL_AGENT_DIR:-$WORK_DIR/linux_serial_agent}"
FLASH_BIN="${FLASH_BIN:-$WORK_DIR/buildroot-2026.02.1/output/images/u-boot-dtb.imx}"
EMMC_IMG="${EMMC_IMG:-$WORK_DIR/buildroot-2026.02.1/output/images/sdcard.img}"
SERIAL_PORT="${SERIAL_PORT:-}"
SERIAL_BAUD="${SERIAL_BAUD:-115200}"
LOGIN_USER="${LOGIN_USER:-}"
LOGIN_PASS="${LOGIN_PASS:-}"
CHECK_CMD="${CHECK_CMD:-uname -a}"
WAIT_RECOVERY_SEC="${WAIT_RECOVERY_SEC:-0}" # 0 = forever

log() { echo "[auto-flash] $*"; }
die() { echo "[auto-flash][ERROR] $*" >&2; exit 1; }
run_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    sudo "$@"
  else
    "$@"
  fi
}

need_file() {
  local f="$1"
  [[ -f "$f" ]] || die "missing file: $f"
}

build_uuu_if_needed() {
  if [[ -x "$UUU_BIN" ]]; then
    return
  fi
  log "uuu not found, building..."
  sudo apt-get update
  sudo apt-get install -y libusb-1.0-0-dev libbz2-dev libzstd-dev pkg-config cmake libssl-dev g++ zlib1g-dev libtinyxml2-dev
  pushd "$WORK_DIR/uuucli" >/dev/null
  env -u CC -u CXX -u AR -u RANLIB -u CROSS_COMPILE cmake -S . -B build -DCMAKE_C_COMPILER=gcc -DCMAKE_CXX_COMPILER=g++
  env -u CC -u CXX -u AR -u RANLIB -u CROSS_COMPILE cmake --build build -j"$(nproc)"
  popd >/dev/null
  [[ -x "$UUU_BIN" ]] || die "uuu build failed"
}

wait_recovery() {
  log "please put board into USB download mode (recovery)"
  local start ts
  start="$(date +%s)"
  while true; do
    if run_root "$UUU_BIN" -lsusb | grep -Eq 'MX6ULL|MX6UL|SDP'; then
      log "detected NXP SDP device"
      return
    fi
    sleep 1
    if [[ "$WAIT_RECOVERY_SEC" != "0" ]]; then
      ts="$(date +%s)"
      if (( ts - start >= WAIT_RECOVERY_SEC )); then
        die "timeout waiting recovery device"
      fi
    fi
  done
}

flash_emmc() {
  log "start flashing eMMC image..."
  run_root "$UUU_BIN" -v -b emmc_all "$FLASH_BIN" "$EMMC_IMG"
  log "flash finished"
}

serial_check() {
  log "start serial login/check..."
  run_root python3 "$WORK_DIR/flash_usb_shell/serial_login_check.py" \
    --serial-agent-dir "$SERIAL_AGENT_DIR" \
    --port "$SERIAL_PORT" \
    --baudrate "$SERIAL_BAUD" \
    --username "$LOGIN_USER" \
    --password "$LOGIN_PASS" \
    --cmd "$CHECK_CMD"
  log "serial check done"
}

main() {
  need_file "$FLASH_BIN"
  need_file "$EMMC_IMG"
  need_file "$WORK_DIR/flash_usb_shell/serial_login_check.py"
  need_file "$SERIAL_AGENT_DIR/trae_serial_terminal_go"

  build_uuu_if_needed
  wait_recovery
  flash_emmc
  serial_check
}

main "$@"
