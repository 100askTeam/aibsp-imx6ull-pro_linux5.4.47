# i.MX6ULL USB 烧录框架

## 原则

- 方式1 `SDP` 与方式2 `Fastboot` 完全独立，不再混用
- 正常应用开发默认使用 `Fastboot`
- 修改 `U-Boot`、内核、驱动、DTB 或完整系统时使用 `SDP`
- 开发前先确认修改范围，再选择烧录方式

## 当前入口映射

- USB 纯烧录：
  - `flash_usb_shell/flash_fastboot_only.sh`
  - `flash_usb_shell/flash_sdp_only.sh`
- 兼容入口：
  - `flash_usb_shell/way2_recovery_flash.sh`
  - `flash_usb_shell/way1_sdp_flash.sh`
- 上层编排：
  - `board_workflows/flash_fastboot_deploy.sh`
  - `board_workflows/flash_sdp_full.sh`
  - `board_workflows/add_pkg_flash_verify.sh`

## 执行前提

- `uuu` 使用 `uuucli/build/uuu/uuu`
- Fastboot 自动流程依赖当前 Linux 环境可见串口节点：`/dev/ttyUSB*` 或 `/dev/ttyACM*`
- 若在虚拟机中运行，需要先透传 USB 转串口设备与板卡 USB 烧录口
- 若缺少串口节点，上层编排会在 `enter-fastboot` / `enter-usb-sdp` 阶段直接失败，这属于现场连接问题，不是脚本逻辑问题

## 纯 USB 脚本

- `flash_usb_shell/flash_fastboot_only.sh`
- `flash_usb_shell/flash_sdp_only.sh`
- `flash_usb_shell/way2_recovery_flash.sh` -> Fastboot USB 兼容入口
- `flash_usb_shell/way1_sdp_flash.sh` -> SDP USB 兼容入口

## 上层编排

- `board_workflows/flash_fastboot_deploy.sh`
- `board_workflows/flash_sdp_full.sh`
- `board_workflows/select_flash_mode.sh`

## 推荐策略

### Fastboot

适用范围：
- `app`
- `package`
- `rootfs`
- `overlay`
- `userland`
- `service`

典型流程：
1. 若系统正常，串口进入 Linux shell
2. 发送 `reboot`
3. 抢占 U-Boot 并执行 `fastboot 0`
4. 主机执行 Fastboot `.uuu` 烧录
5. 烧录后自动串口验证

### SDP

适用范围：
- `system`
- `full`
- `kernel`
- `uboot`
- `driver`
- `dtb`
- `bootloader`

典型流程：
1. 若系统正常，串口进入 Linux shell
2. 发送 `reboot`
3. 抢占 U-Boot 并执行 `bmode usb`
4. 主机执行 `uuu -b emmc_all`
5. 烧录后自动串口验证
