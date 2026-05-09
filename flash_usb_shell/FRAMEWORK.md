# i.MX6ULL 自动烧录与串口联动框架

## 目标

- 人工把板子拨到 USB 烧录模式（Recovery）
- 主机自动识别设备并调用 `uuu` 烧写到 eMMC
- 烧写完成后自动走串口登录与健康检查

## 框架图

```text
┌───────────────────────────── 人工动作 ─────────────────────────────┐
│ 1) 板子断电                                                        │
│ 2) 进入 Recovery (USB 下载模式)                                     │
│ 3) USB 连接到主机                                                  │
└────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌────────────────────────────────────────────────────────────────────┐
│ auto_flash_and_serial.sh                                          │
│                                                                    │
│  A. 检查产物/工具：                                                │
│     - u-boot-dtb.imx                                               │
│     - sdcard.img                                                   │
│     - uuucli/build/uuu/uuu                                         │
│     - linux_serial_agent/trae_serial_terminal_go                  │
│                                                                    │
│  B. 等待烧录设备出现：uuu -lsusb (轮询)                             │
│                                                                    │
│  C. 自动烧录 eMMC：                                                │
│     uuu -v -b emmc_all u-boot-dtb.imx sdcard.img                  │
│                                                                    │
│  D. 自动串口检查：                                                 │
│     serial_login_check.py                                          │
│       ├─ 自动选 /dev/ttyUSB* / /dev/ttyACM*                       │
│       ├─ 可选用户名密码登录（pexpect + picocom）                  │
│       └─ 执行检查命令（默认 uname -a）                             │
└────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
                    ┌───────────────────────┐
                    │ 输出结果与日志         │
                    │ - 烧录成功/失败        │
                    │ - 串口登录与命令输出   │
                    └───────────────────────┘
```

## 入口文件

- `flash_usb_shell/auto_flash_and_serial.sh`
- `flash_usb_shell/serial_login_check.py`
- `flash_usb_shell/add_pkg_flash_verify.sh`

## 一键运行示例

```bash
cd /home/ubuntu/imx6ull-pro_linux5.4.47
WAIT_RECOVERY_SEC=0 \
LOGIN_USER=root \
LOGIN_PASS=123456 \
CHECK_CMD="uname -a" \
./flash_usb_shell/auto_flash_and_serial.sh
```

## 加包+重刷+验证一键示例

```bash
cd /home/ubuntu/imx6ull-pro_linux5.4.47
./flash_usb_shell/add_pkg_flash_verify.sh BR2_PACKAGE_SL "uname -a; which sl; TERM=vt100 sl -l >/dev/null 2>&1; echo SL_RC:$?"
```

说明：
- `WAIT_RECOVERY_SEC=0` 表示无限等待设备进入烧录模式。
- 若不需要自动登录，去掉 `LOGIN_USER/LOGIN_PASS` 即可，脚本会用 `io --send` 执行检查命令。

## 当前项目实机基线（已闭环）

- DTB 基线：`imx6ull-14x14-evk.dtb`
- eMMC 稳定参数：`usdhc2` 采用 4bit + `no-1-8-v` + `max-frequency=50000000`
- 刷写后验收关键日志：
  - `mmcblk1: ... p1 p2`
  - `EXT4-fs (...) mounted`
  - `Welcome to Buildroot`
  - `buildroot login:`

## 故障矩阵（前期错误复盘）

- 现象：`Timeout: Wait for Known USB Device`
  - 定位：未进入 `SDP/Fastboot`
  - 处理：串口打断 U-Boot，执行 `bmode usb` 或 `fastboot 0`
- 现象：`LIBUSB_ERROR_NO_DEVICE`（reset 后）
  - 定位：目标复位瞬断
  - 处理：预期现象，重新枚举继续
- 现象：`_flash.bin not found`
  - 定位：`-b emmc_all` 参数别名未准备
  - 处理：创建 `_flash.bin/_image` 别名，或改用 `flash_from_fb_local.uuu`
- 现象：`Waiting for root device ...` + `mmc1 error -110`
  - 定位：内核侧 eMMC 初始化失败（DTB/时序）
  - 处理：切换并修正 `imx6ull-14x14-evk.dtb` 后重刷
