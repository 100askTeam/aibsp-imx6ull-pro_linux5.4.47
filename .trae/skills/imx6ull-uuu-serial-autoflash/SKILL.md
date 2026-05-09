---
name: "imx6ull-uuu-serial-autoflash"
description: "自动化 i.MX6ULL 的 uuu eMMC 烧录与串口登录检查。用户进入烧录模式后需要自动烧录和自动串口验证时调用。"
---

# i.MX6ULL UUU + Serial Auto Flash

用于把以下两类工具串起来形成一键流程：
- `uuucli/build/uuu/uuu`：USB 下载模式下自动烧写 eMMC
- `linux_serial_agent`：烧录后自动串口登录并执行健康检查

## 何时调用

- 你已经有可用镜像（`u-boot-dtb.imx` + `sdcard.img`）
- 你希望“人手只负责让板子进 recovery，剩下全部自动”
- 你希望烧录后自动通过串口执行 `uname -a` 等检查命令

## 目录与入口

- 主脚本：`flash_usb_shell/auto_flash_and_serial.sh`
- 加包+重刷+验证一键脚本：`flash_usb_shell/add_pkg_flash_verify.sh`
- 串口检查：`flash_usb_shell/serial_login_check.py`
- 框架图文档：`flash_usb_shell/FRAMEWORK.md`

## 先决条件

1. `uuu` 可执行
   - 默认路径：`uuucli/build/uuu/uuu`
   - 若不存在，主脚本会自动安装依赖并编译
2. Buildroot 镜像存在
   - `buildroot-2026.02.1/output/images/u-boot-dtb.imx`
   - `buildroot-2026.02.1/output/images/sdcard.img`
3. 串口工具存在
   - `linux_serial_agent/trae_serial_terminal_go`
4. 如要自动登录（用户名密码）
   - 需要 `picocom` 与 `python3-pexpect`

## 一键执行

```bash
cd /home/ubuntu/imx6ull-pro_linux5.4.47

WAIT_RECOVERY_SEC=0 \
LOGIN_USER=root \
LOGIN_PASS=123456 \
CHECK_CMD="uname -a" \
./flash_usb_shell/auto_flash_and_serial.sh
```

说明：
- `WAIT_RECOVERY_SEC=0`：无限等待板子进入 recovery。
- `LOGIN_USER/LOGIN_PASS` 为空时，会跳过登录流程，直接发送检查命令。
- 如串口自动选口不准确，可指定：
  - `SERIAL_PORT=/dev/ttyUSB0`
  - `SERIAL_BAUD=115200`
- 脚本已自动用 `sudo` 执行 `uuu` 与串口检查，避免 USB/TTY 权限不足。

## 推荐执行顺序

1. 人工将板子拨到 USB 下载模式（Recovery）并接线
2. 运行一键脚本
3. 等待日志输出：
   - 检测到 SDP 设备
   - 开始/完成 eMMC 烧录
   - 串口自动检查结果

## 常见问题

- 报 `Timeout: Wait for Known USB Device`
  - 板子未进 recovery 或 USB 线/供电异常
- 报 `libusb ... requires write access`
  - 需要 root 权限；当前脚本已自动 `sudo`
- 串口登录失败
  - 检查账号密码、波特率、串口节点
- 提示缺少 `picocom` / `pexpect`
  - `sudo apt-get install -y picocom python3-pexpect`

## 实机闭环结论（2026-05）

- 当前 100ask i.MX6ULL Pro 实机启动稳定方案，必须优先使用 `imx6ull-14x14-evk.dtb`（不是 `imx6ull-14x14-evk-emmc.dtb`）。
- 典型异常特征：`Starting kernel ...` 后重启或卡死，同时内核日志出现 `mmc1: error -110`、`Waiting for root device`。
- 已验证有效修复：在 `imx6ull-14x14-evk.dts` 的 `&usdhc2` 使用保守参数（4bit、`no-1-8-v`、`max-frequency=50000000`）后，系统可进入 `buildroot login`。

## 推荐刷写链路（实机更稳）

当板子不容易稳定进 `SDP` 时，优先走 `Fastboot` 链路：

1. 串口打断 U-Boot，执行 `fastboot 0`
2. 主机执行 `flash_from_fb_local.uuu`
3. 复位后串口检查 `EXT4-fs ... mounted` 和 `buildroot login`

示例：

```bash
cd /home/ubuntu/imx6ull-pro_linux5.4.47/buildroot-2026.02.1/output/images
sudo /home/ubuntu/imx6ull-pro_linux5.4.47/uuucli/build/uuu/uuu -v flash_from_fb_local.uuu
```

## 默认执行策略（无需人工按键）

后续默认按以下优先级自动执行，不再要求人工在倒计时按键：

1. 若已在 Linux 串口可登录：
   - 由脚本自动发送 `reboot`，自动抢占 U-Boot，自动执行 `fastboot 0`，再自动 `uuu` 刷写。
2. 若已在 U-Boot 串口：
   - 由脚本自动发送 `fastboot 0`，然后自动 `uuu` 刷写。
3. 若 `reboot_mode=usb_sdp` 链路已安装并生效：
   - 由脚本触发重启并走 SDP 刷写链路。

仅在串口/USB 物理连接缺失时才需要你介入接线或上电。

## 一键“加包并重刷验证”

```bash
cd /home/ubuntu/imx6ull-pro_linux5.4.47
./flash_usb_shell/add_pkg_flash_verify.sh BR2_PACKAGE_SL "uname -a; which sl; TERM=vt100 sl -l >/dev/null 2>&1; echo SL_RC:$?"
```

说明：
- 第一个参数是 Buildroot 包符号（例：`BR2_PACKAGE_HTOP`）。
- 第二个参数是刷写后串口登录的验证命令。

## imx6ull-pro 主板专项说明（串口登录）

仅针对当前 `imx6ull-pro` 实机：
- 当前系统常见为 `root` 无密码直接进 shell，不一定出现 `Password:` 提示。
- 现阶段建议优先使用 `io --send` 直发命令验证，避免等待 `Password:` 超时。
- 计划增强 `serial_login_check.py`：新增“无密码 root 自动登录”分支，检测到 `# ` 提示符时直接执行校验命令。
- `add_pkg_flash_verify.sh` 默认会复用该策略，确保无人值守流程稳定。

## 错误复盘清单（已验证）

- `can't find ext name in path: >_flash.bin`
  - 原因：`uuu -b emmc_all` 需要 `_flash.bin/_image` 别名
  - 修复：在镜像目录创建 `_flash.bin -> u-boot-dtb.imx`、`_image -> sdcard.img`
- `LIBUSB_ERROR_NO_DEVICE`（在 `FB: ucmd reset` 后）
  - 原因：目标复位导致 USB 断链
  - 处理：预期现象，随后重新枚举并继续流程
- `Loading Environment ... bad CRC, using default environment`
  - 影响：U-Boot 环境丢失，可能回退到 `uuucli` 默认链路
  - 处理：重新写入关键环境变量并 `saveenv`
- `mmcroot=/dev/mmcblk1p2` 与实际设备不符
  - 处理：改 `mmcroot`/`bootargs` 后仍需看内核 `mmc` 初始化是否成功；若 `mmc1 -110` 仍在，优先修 DTB
