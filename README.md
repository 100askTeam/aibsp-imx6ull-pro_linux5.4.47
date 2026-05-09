# aibsp-imx6ull-pro_linux5.4.47

`i.MX6ULL Pro` 开发工作区，包含：
- `buildroot-2026.02.1`：系统构建与镜像产出
- `flash_usb_shell`：USB 烧录 + 串口自动化脚本
- `linux_serial_agent`：串口设备发现、自动交互
- `uuucli`：NXP UUU 工具源码与构建产物

## 默认开发流程

1. 配置 Buildroot
```bash
cd buildroot-2026.02.1
make 100ask_imx6ull-pro_defconfig
```

2. 编译镜像
```bash
make -j"$(nproc)"
```

3. 方式1（ROM SDP）刷写
```bash
sudo ./uuucli/build/uuu/uuu -v -b emmc_all \
  ./buildroot-2026.02.1/output/images/u-boot-dtb.imx \
  ./buildroot-2026.02.1/output/images/sdcard.img
```

4. 方式2（U-Boot Fastboot）刷写
```bash
./flash_usb_shell/way2_recovery_flash.sh
```

## 目录迁移约定

- 旧目录 `tools/imx6ull_flash_serial_framework` 已迁移为根目录 `flash_usb_shell`。
- 新增脚本或文档时，统一放在 `flash_usb_shell` 下，避免再回落到 `tools` 目录。

## 子模块说明

本仓库使用 Git 子模块引用上游源码：
- `uboot-imx` -> `https://gitee.com/weidongshan/uboot-imx.git`
- `linux-imx` -> `https://gitee.com/weidongshan/linux-imx.git`
