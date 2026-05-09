#!/usr/bin/env bash
set -euo pipefail

WORK_DIR="${WORK_DIR:-/home/ubuntu/imx6ull-pro_linux5.4.47}"
BR_DIR="${BR_DIR:-$WORK_DIR/buildroot-2026.02.1}"
DEFCONFIG="${DEFCONFIG:-$BR_DIR/configs/100ask_imx6ull-pro_defconfig}"
IMAGES_DIR="${IMAGES_DIR:-$BR_DIR/output/images}"
LINUX_SERIAL_AGENT_DIR="${LINUX_SERIAL_AGENT_DIR:-$WORK_DIR/linux_serial_agent}"
SERIAL_PORT="${SERIAL_PORT:-/dev/ttyACM0}"
SERIAL_BAUD="${SERIAL_BAUD:-115200}"
PKG_SYMBOL="${1:-BR2_PACKAGE_SL}"
VERIFY_CMD="${2:-uname -a; which sl; TERM=vt100 sl -l >/dev/null 2>&1; echo SL_RC:$?}"
U_BOOT_DTS_NAME="${U_BOOT_DTS_NAME:-imx6ull-14x14-evk}"
UUU_BIN="${UUU_BIN:-$WORK_DIR/uuucli/build/uuu/uuu}"
JOBS="${JOBS:-$(nproc)}"

log() { echo "[add-pkg-flash-verify] $*"; }
die() { echo "[add-pkg-flash-verify][ERROR] $*" >&2; exit 1; }
run_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    sudo "$@"
  else
    "$@"
  fi
}

need_file() { [[ -f "$1" ]] || die "missing file: $1"; }
need_bin() { command -v "$1" >/dev/null 2>&1 || die "missing binary: $1"; }

update_defconfig() {
  need_file "$DEFCONFIG"
  if ! grep -q "^${PKG_SYMBOL}=y$" "$DEFCONFIG"; then
    log "enable ${PKG_SYMBOL}=y in defconfig"
    echo "${PKG_SYMBOL}=y" >> "$DEFCONFIG"
  else
    log "${PKG_SYMBOL}=y already enabled"
  fi

  if grep -q '^BR2_LINUX_KERNEL_INTREE_DTS_NAME=' "$DEFCONFIG"; then
    sed -i "s|^BR2_LINUX_KERNEL_INTREE_DTS_NAME=.*|BR2_LINUX_KERNEL_INTREE_DTS_NAME=\"${U_BOOT_DTS_NAME}\"|" "$DEFCONFIG"
  else
    echo "BR2_LINUX_KERNEL_INTREE_DTS_NAME=\"${U_BOOT_DTS_NAME}\"" >> "$DEFCONFIG"
  fi
}

build_images() {
  log "buildroot reconfigure + build"
  (cd "$BR_DIR" && make 100ask_imx6ull-pro_defconfig && make -j"${JOBS}")
  need_file "$IMAGES_DIR/sdcard.img"
  need_file "$IMAGES_DIR/u-boot-dtb.imx"
}

prepare_flash_script() {
  cat > "$IMAGES_DIR/flash_from_fb_local.uuu" <<'EOF'
uuu_version 1.4.193
FB: ucmd setenv fastboot_dev mmc
FB: ucmd mmc dev 1
FB: flash -raw2sparse all sdcard.img
FB: ucmd reset
FB: done
EOF
}

enter_fastboot_automatically() {
  log "auto enter fastboot from serial (${SERIAL_PORT}@${SERIAL_BAUD})"
  run_root python3 - <<PY
import serial,time,sys
port="${SERIAL_PORT}"
baud=${SERIAL_BAUD}
ser=serial.Serial(port, baud, timeout=0.12, write_timeout=1)
buf=""
# Try reboot from Linux shell first; harmless in U-Boot.
for s in [b"\\n", b"\\x03\\x03\\n", b"reboot\\n"]:
    ser.write(s); ser.flush(); time.sleep(0.2)

start=time.time()
sent=False
while time.time()-start < 90:
    b=ser.read(4096)
    if b:
        t=b.decode(errors="ignore")
        buf=(buf+t)[-40000:]
        if ("Hit any key to stop autoboot" in buf) or ("=> " in buf):
            ser.write(b"\\x03\\x03\\r"); ser.flush(); time.sleep(0.12)
            ser.write(b"fastboot 0\\r"); ser.flush(); time.sleep(0.2)
            sent=True
            break
    time.sleep(0.02)
ser.close()
if not sent:
    print("failed to enter fastboot automatically", file=sys.stderr)
    sys.exit(2)
PY
}

flash_with_retry() {
  local i
  for i in 1 2 3; do
    log "uuu fastboot flash attempt ${i}/3"
    if run_root "$UUU_BIN" -v flash_from_fb_local.uuu >/tmp/add_pkg_flash_uuu.log 2>&1; then
      cat /tmp/add_pkg_flash_uuu.log
      return
    fi
    cat /tmp/add_pkg_flash_uuu.log
    # On i.MX6ULL, target reset often disconnects USB right after successful flash.
    if grep -q "flash -raw2sparse all sdcard.img" /tmp/add_pkg_flash_uuu.log \
      && grep -q "Start Cmd:FB: ucmd reset" /tmp/add_pkg_flash_uuu.log \
      && grep -q "LIBUSB_ERROR_NO_DEVICE" /tmp/add_pkg_flash_uuu.log; then
      log "treat LIBUSB_ERROR_NO_DEVICE after reset as success"
      return
    fi
    if grep -q "Failure claim interface" /tmp/add_pkg_flash_uuu.log; then
      sleep 1
      continue
    fi
    break
  done
  die "uuu flash failed"
}

verify_over_serial() {
  need_file "$WORK_DIR/flash_usb_shell/serial_login_check.py"
  need_file "$LINUX_SERIAL_AGENT_DIR/trae_serial_terminal_go"
  need_bin picocom
  need_bin python3
  log "verify boot/login and command over serial"
  run_root python3 "$WORK_DIR/flash_usb_shell/serial_login_check.py" \
    --serial-agent-dir "$LINUX_SERIAL_AGENT_DIR" \
    --port "$SERIAL_PORT" \
    --baudrate "$SERIAL_BAUD" \
    --username root \
    --password "" \
    --cmd "$VERIFY_CMD"
}

main() {
  need_file "$DEFCONFIG"
  need_file "$LINUX_SERIAL_AGENT_DIR/trae_serial_terminal_go"
  need_file "$UUU_BIN"
  update_defconfig
  build_images
  prepare_flash_script
  enter_fastboot_automatically
  (cd "$IMAGES_DIR" && flash_with_retry)
  sleep 5
  verify_over_serial
  log "done"
}

main "$@"
