#!/usr/bin/env bash
set -euo pipefail

WORK_DIR="${WORK_DIR:-/home/ubuntu/imx6ull-pro_linux5.4.47}"
CHANGE_SCOPE="${CHANGE_SCOPE:-system}"
exec "$WORK_DIR/board_workflows/flash_sdp_full.sh" "$@"
