#!/usr/bin/env bash
set -euo pipefail

WORK_DIR="${WORK_DIR:-/home/ubuntu/imx6ull-pro_linux5.4.47}"
CHANGE_SCOPE="${1:-${CHANGE_SCOPE:-}}"
EXECUTE_NOW="${EXECUTE_NOW:-0}"

usage() {
  cat <<'EOF'
Usage:
  ./board_workflows/select_flash_mode.sh <scope>

Fastboot scopes:
  app package rootfs overlay userland service

SDP scopes:
  system full kernel uboot driver dtb bootloader

Example:
  ./board_workflows/select_flash_mode.sh app
  EXECUTE_NOW=1 ./board_workflows/select_flash_mode.sh kernel
EOF
}

choose_mode() {
  case "$CHANGE_SCOPE" in
    app|package|rootfs|overlay|userland|service)
      echo fastboot
      return 0
      ;;
    system|full|kernel|uboot|driver|dtb|bootloader)
      echo sdp
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

main() {
  if [[ -z "$CHANGE_SCOPE" ]]; then
    usage
    exit 2
  fi

  mode="$(choose_mode)" || {
    echo "[select-flash][ERROR] unknown scope: $CHANGE_SCOPE" >&2
    usage >&2
    exit 2
  }

  echo "[select-flash] scope=$CHANGE_SCOPE -> mode=$mode"

  if [[ "$EXECUTE_NOW" != "1" ]]; then
    if [[ "$mode" == "fastboot" ]]; then
      echo "[select-flash] command: CHANGE_SCOPE=$CHANGE_SCOPE $WORK_DIR/board_workflows/flash_fastboot_deploy.sh"
    else
      echo "[select-flash] command: CHANGE_SCOPE=$CHANGE_SCOPE $WORK_DIR/board_workflows/flash_sdp_full.sh"
    fi
    return 0
  fi

  if [[ "$mode" == "fastboot" ]]; then
    CHANGE_SCOPE="$CHANGE_SCOPE" "$WORK_DIR/board_workflows/flash_fastboot_deploy.sh"
  else
    CHANGE_SCOPE="$CHANGE_SCOPE" "$WORK_DIR/board_workflows/flash_sdp_full.sh"
  fi
}

main "$@"
