#!/usr/bin/env bash
set -euo pipefail

WORK_DIR="${WORK_DIR:-/home/ubuntu/imx6ull-pro_linux5.4.47}"
SERIAL_AGENT_DIR="${SERIAL_AGENT_DIR:-$WORK_DIR/linux_serial_agent}"
SERIAL_PORT="${SERIAL_PORT:-}"
SERIAL_BAUD="${SERIAL_BAUD:-115200}"
LOGIN_USER="${LOGIN_USER:-root}"
LOGIN_PASS="${LOGIN_PASS:-}"
CHECK_CMD="${CHECK_CMD:-uname -a}"
CHANGE_SCOPE="${CHANGE_SCOPE:-system}"
VERIFY_AFTER_FLASH="${VERIFY_AFTER_FLASH:-1}"
ENTER_SDP_VIA_SERIAL="${ENTER_SDP_VIA_SERIAL:-1}"

log() { echo "[sdp-flow] $*"; }
die() { echo "[sdp-flow][ERROR] $*" >&2; exit 1; }
need_file() { [[ -f "$1" ]] || die "missing file: $1"; }

ensure_scope_is_sdp() {
  case "$CHANGE_SCOPE" in
    system|full|kernel|uboot|driver|dtb|bootloader)
      return 0
      ;;
    *)
      die "scope '$CHANGE_SCOPE' is not an sdp scope. Use select_flash_mode.sh or set CHANGE_SCOPE=system/full/kernel/uboot/driver/dtb/bootloader"
      ;;
  esac
}

enter_sdp() {
  if [[ "$ENTER_SDP_VIA_SERIAL" != "1" ]]; then
    log "skip serial stage, expect board already in sdp"
    return 0
  fi
  log "request sdp from current Linux/U-Boot serial session"
  python3 "$WORK_DIR/linux_serial_agent/serial_agent_cli.py" enter-usb-sdp \
    --port "$SERIAL_PORT" \
    --baudrate "$SERIAL_BAUD" \
    --login-user "$LOGIN_USER" \
    --login-password "$LOGIN_PASS"
}

verify_after_flash() {
  if [[ "$VERIFY_AFTER_FLASH" != "1" ]]; then
    log "skip serial verification"
    return 0
  fi
  log "verify system after sdp flashing"
  python3 "$WORK_DIR/linux_serial_agent/serial_agent_cli.py" login-check \
    --serial-agent-dir "$SERIAL_AGENT_DIR" \
    --port "$SERIAL_PORT" \
    --baudrate "$SERIAL_BAUD" \
    --username "$LOGIN_USER" \
    --password "$LOGIN_PASS" \
    --cmd "$CHECK_CMD"
}

main() {
  need_file "$WORK_DIR/linux_serial_agent/serial_agent_cli.py"
  need_file "$WORK_DIR/flash_usb_shell/flash_sdp_only.sh"
  ensure_scope_is_sdp
  log "scope=$CHANGE_SCOPE -> use sdp full-system flashing"
  enter_sdp
  "$WORK_DIR/flash_usb_shell/flash_sdp_only.sh"
  sleep 8
  verify_after_flash
}

main "$@"
