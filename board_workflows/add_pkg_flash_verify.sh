#!/usr/bin/env bash
set -euo pipefail

WORK_DIR="${WORK_DIR:-/home/ubuntu/imx6ull-pro_linux5.4.47}"
BR_DIR="${BR_DIR:-$WORK_DIR/buildroot-2026.02.1}"
DEFCONFIG="${DEFCONFIG:-$BR_DIR/configs/100ask_imx6ull-pro_defconfig}"
PKG_SYMBOL="${1:-BR2_PACKAGE_SL}"
VERIFY_CMD="${2:-uname -a; which sl; TERM=vt100 sl -l >/dev/null 2>&1; echo SL_RC:$?}"
U_BOOT_DTS_NAME="${U_BOOT_DTS_NAME:-imx6ull-14x14-evk-emmc}"
JOBS="${JOBS:-$(nproc)}"

log() { echo "[add-pkg-flash-verify] $*"; }
die() { echo "[add-pkg-flash-verify][ERROR] $*" >&2; exit 1; }
need_file() { [[ -f "$1" ]] || die "missing file: $1"; }

update_defconfig() {
  need_file "$DEFCONFIG"
  if ! grep -q "^${PKG_SYMBOL}=y$" "$DEFCONFIG"; then
    log "enable ${PKG_SYMBOL}=y in defconfig"
    echo "${PKG_SYMBOL}=y" >> "$DEFCONFIG"
  else
    log "${PKG_SYMBOL}=y already enabled"
  fi

  if grep -q '^BR2_LINUX_KERNEL_INTREE_DTS_NAME=' "$DEFCONFIG"; then
    sed -i "s|^BR2_LINUX_KERNEL_INTREE_DTS_NAME=.*|BR2_LINUX_KERNEL_INTREE_DTS_NAME=\\\"${U_BOOT_DTS_NAME}\\\"|" "$DEFCONFIG"
  else
    echo "BR2_LINUX_KERNEL_INTREE_DTS_NAME=\"${U_BOOT_DTS_NAME}\"" >> "$DEFCONFIG"
  fi
}

build_images() {
  log "buildroot reconfigure + build"
  (cd "$BR_DIR" && make 100ask_imx6ull-pro_defconfig && make -j"${JOBS}")
}

main() {
  update_defconfig
  build_images
  CHANGE_SCOPE=package CHECK_CMD="$VERIFY_CMD" "$WORK_DIR/board_workflows/flash_fastboot_deploy.sh"
}

main "$@"
