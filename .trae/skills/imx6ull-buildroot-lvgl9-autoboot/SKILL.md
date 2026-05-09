---
name: "imx6ull-buildroot-lvgl9-autoboot"
description: "在 Buildroot 为 i.MX6ULL 增加 LVGL9 预览示例并开机自启，且自动编译/烧录/串口验证。用户要求屏幕演示自动启动时调用。"
---

# i.MX6ULL Buildroot LVGL9 AutoBoot

适用场景：
- 用户要求在 `buildroot-2026.02.1` 集成 `lvgl9` 示例
- 目标是上电自动启动预览界面（fbdev/evdev）
- 需要闭环执行：改配置 -> 编译 -> `uuu` 烧录 -> 串口验证

## 1) 板级与目录约定

```bash
WORK=/home/ubuntu/imx6ull-pro_linux5.4.47
BR=$WORK/buildroot-2026.02.1
IMG=$BR/output/images
```

默认板级配置：
- `configs/100ask_imx6ull-pro_defconfig`
- `BR2_LINUX_KERNEL_INTREE_DTS_NAME="imx6ull-14x14-evk"`

## 2) 新增 Buildroot 包 `lvgl9-demo`

创建目录：
```bash
mkdir -p $BR/package/lvgl9-demo/src
```

必须包含文件：
- `package/lvgl9-demo/Config.in`
- `package/lvgl9-demo/lvgl9-demo.mk`
- `package/lvgl9-demo/src/lv_conf.h`
- `package/lvgl9-demo/src/lvgl9_demo_main.c`
- `package/lvgl9-demo/src/lvgl9_preview_ui.c`

关键构建点：
- 源码取自 `lvgl v9.2.2`
- 编译定义：`-DLV_CONF_PATH=lv_conf.h`
- 启用：`LV_USE_LINUX_FBDEV=1`、`LV_USE_EVDEV=1`
- 输出：`/usr/bin/lvgl9-demo`

## 3) 接入 Buildroot 菜单和 defconfig

1. 在 `package/Config.in` 的 Graphics 分组加入：
```make
source "package/lvgl9-demo/Config.in"
```

2. 在 `configs/100ask_imx6ull-pro_defconfig` 增加：
```make
BR2_ROOTFS_OVERLAY="board/100ask/imx6ull-pro/rootfs-overlay"
BR2_PACKAGE_LVGL9_DEMO=y
```

## 4) 开机自启动脚本

新增：
- `board/100ask/imx6ull-pro/rootfs-overlay/etc/init.d/S99lvgl9-demo`

脚本约束：
- 可执行权限 `0755`
- 默认参数：`/dev/fb0` 和 `/dev/input/event0`
- 后台启动并写 PID 到 `/var/run/lvgl9-demo.pid`
- 日志写入 `/var/log/lvgl9-demo.log`

## 5) 编译镜像

```bash
cd $BR
make 100ask_imx6ull-pro_defconfig
make -j8
```

产物检查：
```bash
ls -lh $IMG
```

至少确认：
- `u-boot-dtb.imx`
- `sdcard.img`
- `zImage`
- `rootfs.ext2`

## 6) 自动烧录与串口验证

推荐一键闭环：
```bash
SERIAL_PORT=/dev/ttyACM0 SERIAL_BAUD=115200 \
$WORK/flash_usb_shell/add_pkg_flash_verify.sh \
BR2_PACKAGE_LVGL9_DEMO \
"uname -a; ls -l /usr/bin/lvgl9-demo; ls -l /etc/init.d/S99lvgl9-demo"
```

说明：
- 脚本会自动抢占串口并让板子进入 `fastboot 0`
- `uuu` 刷写后若在 `reset` 后出现 `LIBUSB_ERROR_NO_DEVICE`，按已刷完处理

## 7) 串口登录兼容要点

当前机型可能出现：
- `login:` 后不出现 `Password:`，直接进 `#`

应保证串口登录逻辑支持：
- 输入用户名后，允许直接命中 shell prompt，不强依赖 `Password:`

## 8) 验证通过判据

串口执行以下命令应满足：
```bash
uname -a
ls -l /usr/bin/lvgl9-demo
ls -l /etc/init.d/S99lvgl9-demo
pidof lvgl9-demo || true
ps | grep lvgl9-demo | grep -v grep || true
tail -n 40 /var/log/lvgl9-demo.log || true
```

成功判据：
- 二进制存在且可执行
- `S99lvgl9-demo` 存在且可执行
- `lvgl9-demo` 进程存在（示例：`/usr/bin/lvgl9-demo /dev/fb0 /dev/input/event0`）
