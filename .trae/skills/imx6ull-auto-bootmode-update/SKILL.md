---
name: "imx6ull-auto-bootmode-update"
description: "为 i.MX6ULL 配置无拨码自动升级：支持 reboot 后自动进 ROM USB(SDP) 或 U-Boot Recovery(Fastboot)。用户要做无人值守刷写时调用。"
---

# i.MX6ULL Auto Bootmode Update

## 目标

在不手动拨码的前提下，实现两种升级入口：
- 方式1：`reboot` 后自动进入 **ROM USB SDP**（给 uuu `-b emmc_all` 用）
- 方式2：`reboot` 后自动进入 **U-Boot Recovery/Fastboot**（给 uuu `FB:` 或 fastboot 用）

默认引用规则（后续执行默认按此走）：
- 优先使用方式2（Recovery/Fastboot），因为在当前实机更稳定且不依赖 SDP 枚举窗口。
- 方式1作为可选链路保留，用于需要 ROM SDP 的场景。

## 文件位置

- 模式安装命令：`flash_usb_shell/uboot_mode_setup.txt`
- Linux 触发脚本：`flash_usb_shell/linux_reboot_mode.sh`
- Recovery 刷写脚本：`flash_usb_shell/way2_recovery_flash.sh`
- 方案说明：`flash_usb_shell/BOOT_MODE_STRATEGY.md`

## 先决条件

1. U-Boot 支持 `bmode` 与 `fastboot`（当前工程已具备）
2. Linux 安装 `u-boot-tools`（提供 `fw_setenv`）
3. 正确配置 `/etc/fw_env.config`

## 一次性安装（U-Boot）

在 U-Boot 控制台执行 `uboot_mode_setup.txt` 里的命令，完成：
- 保存原始 `bootcmd`
- 注入 `reboot_mode` 分支
- 新增 `reboot_to_usb_sdp / reboot_to_recovery / reboot_to_normal`

## Linux 触发方式

```bash
cd /home/ubuntu/imx6ull-pro_linux5.4.47
./flash_usb_shell/linux_reboot_mode.sh usb_sdp
# 或
./flash_usb_shell/linux_reboot_mode.sh recovery
```

## U-Boot 触发方式

```bash
run reboot_to_usb_sdp
# 或
run reboot_to_recovery
```

## 方式1实测命令（主机侧）

```bash
cd /home/ubuntu/imx6ull-pro_linux5.4.47/buildroot-2026.02.1/output/images
cat > test_mode1_usb_sdp.uuu <<'EOF'
uuu_version 1.4.193
SDP: boot -f u-boot-dtb.imx -scanlimited 0x800000
FB: ucmd mmc dev 1
FB: ucmd setenv reboot_mode usb_sdp
FB: ucmd saveenv
FB: ucmd reset
FB: done
EOF
sudo /home/ubuntu/imx6ull-pro_linux5.4.47/uuucli/build/uuu/uuu -v test_mode1_usb_sdp.uuu
```

说明：
- `FB: ucmd reset` 后出现 `LIBUSB_ERROR_NO_DEVICE` 通常是目标复位导致 USB 断开，属预期现象。
- 用 `uuu -lsusb` 再确认是否出现 `MX6ULL SDP`。
- 若硬件拨码已固定 USB 下载，方式1与硬件行为叠加，现象都会是进 SDP。

## Recovery 下主机刷写

```bash
cd /home/ubuntu/imx6ull-pro_linux5.4.47
CHANGE_SCOPE=package ./board_workflows/flash_fastboot_deploy.sh
```

## 无人值守执行约定

- 当串口与 USB 已连接时，后续默认由脚本自动完成：
  - Linux 下 `reboot` -> 抢占 U-Boot -> `fastboot 0` -> `uuu` 刷写 -> 串口验证
  - U-Boot 下直接 `fastboot 0` -> `uuu` 刷写 -> 串口验证
- 不再要求人工卡倒计时按键；人工仅在“物理未连接/未上电”时介入。

## 串口自动校验联动

刷写完成后可接：
- `board_workflows/flash_fastboot_deploy.sh`
- `board_workflows/flash_sdp_full.sh`

用于自动串口登录并执行健康检查命令。

### imx6ull-pro 主板备注

- 当前 `imx6ull-pro` 常见登录形态为 `root` 无密码直接进入 `#`。
- 因此在该主板上，串口验证默认优先走“无密码自动登录/直发命令”路径。
- 若在虚拟机中执行，无论是串口还是 USB 烧录口，都需要先透传到当前 Linux 环境。

## 现场排障要点（已实测）

- 若设置 `reboot_mode=usb_sdp` 后仍然 `Normal Boot`：
  - 先检查 `bootcmd` 是否真的包含 `reboot_mode` 分支；只写变量不改 `bootcmd` 不会生效。
- 若频繁被打断停在 `=>`：
  - 禁止后台持续发送 `Ctrl+C`，先恢复正常自启动再排障。
- 若刷写后反复重启且卡在 `Starting kernel ...`：
  - 优先排查 DTB/eMMC 时序问题，而不是先怀疑烧录流程。
- 若要清理模式分流影响：
  - 在 U-Boot 执行 `setenv reboot_mode; saveenv; reset`
