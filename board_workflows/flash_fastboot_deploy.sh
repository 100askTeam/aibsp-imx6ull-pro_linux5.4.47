#!/usr/bin/env bash
set -euo pipefail

WORK_DIR="${WORK_DIR:-/home/ubuntu/imx6ull-pro_linux5.4.47}"
SERIAL_AGENT_DIR="${SERIAL_AGENT_DIR:-$WORK_DIR/linux_serial_agent}"
SERIAL_PORT="${SERIAL_PORT:-}"
SERIAL_BAUD="${SERIAL_BAUD:-115200}"
LOGIN_USER="${LOGIN_USER:-root}"
LOGIN_PASS="${LOGIN_PASS:-}"
VERIFY_LOGIN_USER="${VERIFY_LOGIN_USER:-}"
VERIFY_LOGIN_PASS="${VERIFY_LOGIN_PASS:-}"
CHECK_CMD="${CHECK_CMD:-uname -a}"
CHANGE_SCOPE="${CHANGE_SCOPE:-app}"
VERIFY_AFTER_FLASH="${VERIFY_AFTER_FLASH:-1}"

log() { echo "[fastboot-flow] $*"; }
die() { echo "[fastboot-flow][ERROR] $*" >&2; exit 1; }
need_file() { [[ -f "$1" ]] || die "missing file: $1"; }

ensure_scope_is_fastboot() {
  case "$CHANGE_SCOPE" in
    app|package|rootfs|overlay|userland|service)
      return 0
      ;;
    *)
      die "scope '$CHANGE_SCOPE' is not a fastboot scope. Use select_flash_mode.sh or set CHANGE_SCOPE=app/package/rootfs/overlay/userland/service"
      ;;
  esac
}

enter_fastboot() {
  log "strict fastboot path: Linux shell reboot -> U-Boot -> setenv fastboot_dev mmc; mmc dev 1; fastboot 0"
  python3 "$WORK_DIR/linux_serial_agent/serial_agent_cli.py" uboot-command \
    --port "$SERIAL_PORT" \
    --baudrate "$SERIAL_BAUD" \
    --login-user "$LOGIN_USER" \
    --login-password "$LOGIN_PASS" \
    --command "setenv fastboot_dev mmc; mmc dev 1; fastboot 0"
}

verify_after_flash() {
  if [[ "$VERIFY_AFTER_FLASH" != "1" ]]; then
    log "skip serial verification"
    return 0
  fi
  if [[ -n "$VERIFY_LOGIN_USER" ]]; then
    log "verify system after fastboot flashing with login mode"
  else
    log "verify system after fastboot flashing with direct-send mode"
  fi
  python3 "$WORK_DIR/linux_serial_agent/serial_agent_cli.py" login-check \
    --serial-agent-dir "$SERIAL_AGENT_DIR" \
    --port "$SERIAL_PORT" \
    --baudrate "$SERIAL_BAUD" \
    --username "$VERIFY_LOGIN_USER" \
    --password "$VERIFY_LOGIN_PASS" \
    --cmd "$CHECK_CMD"
}

main() {
  need_file "$WORK_DIR/linux_serial_agent/serial_agent_cli.py"
  need_file "$WORK_DIR/flash_usb_shell/flash_fastboot_only.sh"
  ensure_scope_is_fastboot
  log "scope=$CHANGE_SCOPE -> use fastboot development flashing"
  enter_fastboot || die "failed to reboot into U-Boot fastboot path. If the target is hung or serial cannot抢占, please do a manual reset and rerun."
  "$WORK_DIR/flash_usb_shell/flash_fastboot_only.sh"
  sleep 5
  verify_after_flash
}

main "$@"
