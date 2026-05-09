# i.MX6ULL 无拨码自动升级策略（方式1 + 方式2）

## 结论先说

- **方式1（自动进 ROM USB 烧录）可行**：基于 U-Boot `bmode usb`。
- **方式2（自动进 U-Boot Recovery/Fastboot）可行**：基于 U-Boot `fastboot 0`。
- 两种方式都可从 Linux 发起（通过 `fw_setenv + reboot`），也可在 U-Boot 命令行发起。

---

## 方式1：自动复位进入 USB SDP（ROM 下载模式）

### 原理

U-Boot 已支持 `CONFIG_CMD_BMODE`，`bmode usb` 会写 `SRC_GPR9/GPR10`，随后复位，ROM 按覆盖的 boot cfg 进入 USB SDP。

### 一次性安装（U-Boot）

把以下内容粘贴到 U-Boot（见 `uboot_mode_setup.txt`）：

- 保存当前 `bootcmd` 到 `bootcmd_normal`
- 在 `bootcmd` 前面增加 `reboot_mode` 判断：
  - `usb_sdp` -> `bmode usb`
  - `recovery` -> `fastboot 0`
  - 空 -> 正常启动
- 新增命令：
  - `run reboot_to_usb_sdp`
  - `run reboot_to_recovery`
  - `run reboot_to_normal`

### Linux 侧触发

```bash
cd /home/ubuntu/imx6ull-pro_linux5.4.47
./flash_usb_shell/linux_reboot_mode.sh usb_sdp
```

> 需要 `fw_setenv`（`u-boot-tools`）和正确的 `/etc/fw_env.config`。

### U-Boot 侧触发

```bash
run reboot_to_usb_sdp
```

---

## 方式2：自动复位进入 U-Boot Recovery（Fastboot 模式）

### 原理

通过 `reboot_mode=recovery` 让 U-Boot 启动后直接执行 `fastboot 0`，主机即可用 `uuu`/`fastboot` 刷写，不依赖 ROM SDP。

### Linux 侧触发

```bash
cd /home/ubuntu/imx6ull-pro_linux5.4.47
./flash_usb_shell/linux_reboot_mode.sh recovery
```

### U-Boot 侧触发

```bash
run reboot_to_recovery
```

### 主机刷写（Recovery/Fastboot 下）

```bash
cd /home/ubuntu/imx6ull-pro_linux5.4.47
./flash_usb_shell/way2_recovery_flash.sh
```

---

## 与自动串口校验联动

沿用已有：

```bash
cd /home/ubuntu/imx6ull-pro_linux5.4.47
WAIT_RECOVERY_SEC=0 LOGIN_USER=root LOGIN_PASS=123456 \
./flash_usb_shell/auto_flash_and_serial.sh
```

建议：
- 工厂刷机优先方式1（ROM SDP）
- 开发迭代优先方式2（U-Boot Recovery/Fastboot）

---

## 注意事项

- `bmode usb` 依赖当前 U-Boot 已启动并支持 `CONFIG_CMD_BMODE`。
- Linux 触发需要 `fw_setenv` 可正确写入 U-Boot 环境。
- 若要“普通 `reboot` 自动变成升级重启”，必须在 reboot 前先设置 `reboot_mode`。
