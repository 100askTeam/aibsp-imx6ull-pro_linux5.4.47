# CLOUDE

本文件定义本地默认开发约定，作为日常开发基线。

## 环境约定

- 工作目录：`/home/ubuntu/imx6ull-pro_linux5.4.47`
- 串口默认：`/dev/ttyACM0`，`115200`
- UUU 默认：`./uuucli/build/uuu/uuu`

## Buildroot 约定

- defconfig：`buildroot-2026.02.1/configs/100ask_imx6ull-pro_defconfig`
- U-Boot 源：`https://gitee.com/weidongshan/uboot-imx.git`
- Kernel 源：`https://gitee.com/weidongshan/linux-imx.git`
- 板级 DTB 基线：`imx6ull-14x14-evk`

## 烧录与验证约定

- 自动化脚本目录：`flash_usb_shell`
- 方式1：ROM SDP (`-b emmc_all`)
- 方式2：U-Boot Fastboot (`way2_recovery_flash.sh`)
- 验证优先走 root 无密码/直发命令路径

## 提交约定

- 变更涉及脚本路径时，同时更新：
  - `flash_usb_shell` 内部引用
  - `.trae/skills` 相关调用文档
- 新增流程文档默认补充到 `README.md`
