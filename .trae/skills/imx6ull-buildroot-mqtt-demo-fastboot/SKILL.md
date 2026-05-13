---
name: "imx6ull-buildroot-mqtt-demo-fastboot"
description: "为 i.MX6ULL 新增 Buildroot 本地 mqtt-demo 包并走 Fastboot 自动烧写与串口验证。用户要验证 MQTT 本机回环应用时调用。"
---

# i.MX6ULL Buildroot MQTT Demo Fastboot

用于在当前 `imx6ull-pro` 仓库内完成以下闭环：
- 新增或维护 `Buildroot` 本地 `mqtt-demo` 包
- 重新编译 `sdcard.img`
- 从 Linux 串口自动 `reboot` 抢占 `U-Boot`
- 进入 `fastboot 0` 并用 `uuu` 自动烧写
- 系统启动后自动重启 `mosquitto` 并执行 `mqtt-demo`
- 收集 MQTT 回环验证结果

## 何时调用

- 用户要增加一个 MQTT 示例应用并验证整条开发链路
- 用户要验证 `mosquitto broker + mqtt-demo client` 的本机回环
- 用户要求“自动编译 -> 自动烧写 -> 自动串口运行验证”

## 当前包结构

```text
buildroot-2026.02.1/package/mqtt-demo/
├── Config.in
├── mqtt-demo.mk
└── src/mqtt_demo.c
```

## 包实现约定

- `BR2_PACKAGE_MQTT_DEMO`
  - 依赖动态库工具链
  - `select BR2_PACKAGE_MOSQUITTO`
  - `select BR2_PACKAGE_MOSQUITTO_BROKER`
- `mqtt-demo.mk`
  - 本地源码方式：`SITE_METHOD = local`
  - 链接：`-lmosquitto -lpthread`
- `mqtt_demo.c`
  - 连接 `127.0.0.1:1883`
  - 订阅 `imx6ull/mqtt-demo`
  - 发布时间戳消息
  - 收到相同 payload 后输出 `MQTT_DEMO_OK`

## 架构框图

```text
Buildroot mqtt-demo package
          |
          v
make -> output/images/sdcard.img
          |
          v
board_workflows/flash_fastboot_deploy.sh
          |
          +--> linux_serial_agent
          |     reboot -> U-Boot -> fastboot 0
          |
          +--> flash_usb_shell
                uuu flash -raw2sparse all sdcard.img
          |
          v
Target Linux shell
          |
          v
restart mosquitto -> run mqtt-demo -> collect loopback result
```

## 标准操作流程图

```text
新增或修改 mqtt-demo
        |
        v
接入 package/Config.in 与 defconfig
        |
        v
make 100ask_imx6ull-pro_defconfig && make
        |
        v
确认 target/usr/bin/mqtt-demo 已生成
        |
        v
串口进入 Linux shell
        |
        v
脚本发送 reboot -> 抢 U-Boot -> fastboot 0
        |
        v
uuu 自动烧写 sdcard.img
        |
        v
系统启动 -> root 登录
        |
        v
重启 /etc/init.d/S50mosquitto
        |
        v
执行 mqtt-demo
        |
        v
检查 MQTT_DEMO_OK 与 MQTT_DEMO_RC:0
```

## 关键文件

- 包入口：`buildroot-2026.02.1/package/mqtt-demo/Config.in`
- 构建规则：`buildroot-2026.02.1/package/mqtt-demo/mqtt-demo.mk`
- 示例源码：`buildroot-2026.02.1/package/mqtt-demo/src/mqtt_demo.c`
- Buildroot 接入：`buildroot-2026.02.1/package/Config.in`
- defconfig：`buildroot-2026.02.1/configs/100ask_imx6ull-pro_defconfig`
- 编排入口：`board_workflows/flash_fastboot_deploy.sh`

## 推荐验证命令

```bash
echo MQTT_VERIFY_STAGE2
test -x /etc/init.d/S50mosquitto && /etc/init.d/S50mosquitto restart >/dev/null 2>&1 || true
sleep 2
which mqtt-demo
mqtt-demo
echo MQTT_DEMO_RC:$?
```

## 已验证结果格式

```text
MQTT_VERIFY_STAGE2
/usr/bin/mqtt-demo
mqtt-demo: received topic=imx6ull/mqtt-demo payload=mqtt-demo-xxxx
mqtt-demo: loopback success topic=imx6ull/mqtt-demo payload=mqtt-demo-xxxx
MQTT_DEMO_OK
MQTT_DEMO_RC:0
```

## 注意事项

- 当前 `imx6ull-pro` 板上默认更稳的 DTS 仍是 `imx6ull-14x14-evk`
- `Fastboot` 链路里，串口负责控制，`uuu` 只负责镜像传输
- `FB: ucmd reset` 后若出现 `LIBUSB_ERROR_NO_DEVICE`，通常是复位断链，属预期现象
- 若系统未正常启动或内核崩溃，应改走 `SDP` 流程，而不是继续套用 `Fastboot`
