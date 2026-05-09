# 100ASK_IMX6ULL-PRO linux5.4.47 AI 全自动开发

本仓库是 `i.MX6ULL Pro` 的完整交付工作区，目标是：
- 用 `Buildroot` 统一构建 `U-Boot + Kernel + RootFS + 镜像`
- 用 `uuu` 完成 USB 烧录（SDP/Fastboot 两种链路）
- 用串口自动化脚本完成刷后登录与健康检查

## 1. 源码框架架构图

```text
┌──────────────────────────────────────────────────────────────────────┐
│                       aibsp-imx6ull-pro_linux5.4.47                 │
├──────────────────────────────────────────────────────────────────────┤
│ buildroot-2026.02.1                                                  │
│  ├─ configs/100ask_imx6ull-pro_defconfig                             │
│  ├─ package/ (含 lvgl9-demo 等包)                                    │
│  ├─ board/100ask/imx6ull-pro/                                        │
│  └─ output/images/  -> 产出 u-boot-dtb.imx, zImage, dtb, sdcard.img │
│                     │                                                 │
│                     ▼                                                 │
│ flash_usb_shell                                                      │
│  ├─ auto_flash_and_serial.sh      (方式1/通用自动化)                 │
│  ├─ add_pkg_flash_verify.sh       (加包->编译->刷写->串口验证)       │
│  ├─ way2_recovery_flash.sh        (方式2 Fastboot刷写入口)           │
│  ├─ *.uuu                         (uuu脚本)                          │
│  └─ serial_login_check.py         (调用 linux_serial_agent)          │
│                     │                                                 │
│                     ▼                                                 │
│ linux_serial_agent                                                    │
│  └─ trae_serial_terminal_go + pexpect 封装                           │
│                     │                                                 │
│                     ▼                                                 │
│ uuucli/build/uuu/uuu  <---- USB ---->  i.MX6ULL (SDP/Fastboot)      │
│                                                                      │
│ 子模块：                                                             │
│  uboot-imx (gitee)     linux-imx (gitee)                             │
└──────────────────────────────────────────────────────────────────────┘
```

## 2. 核心目录差异与职责

### 2.1 `buildroot-2026.02.1`
- 角色：系统集成与产物总入口。
- 负责：工具链配置、RootFS 选包、Kernel/U-Boot 拉取与编译、镜像打包。
- 典型输入：`configs/100ask_imx6ull-pro_defconfig`。
- 典型输出：`output/images/u-boot-dtb.imx`、`sdcard.img`、`zImage`、`*.dtb`。

### 2.2 `linux-imx`（子模块）
- 角色：内核源码上游。
- 负责：驱动、设备树、内核配置能力。
- 与 Buildroot 关系：Buildroot 按 defconfig 中的 `CUSTOM_GIT` 配置从在线仓库获取（仓库中也保留子模块用于开发对比/补丁管理）。

### 2.3 `uboot-imx`（子模块）
- 角色：Bootloader 源码上游。
- 负责：上电初始化、启动内核、fastboot/bmode 等升级入口。
- 与 Buildroot 关系：同样由 Buildroot 的 `CUSTOM_GIT` 逻辑取源码构建。

### 2.4 `linux_serial_agent`
- 角色：串口自动化基础层。
- 负责：串口枚举、发命令、自动登录（含 `login:`/`Password:`/直进 shell 场景）。
- 典型调用方：`flash_usb_shell/serial_login_check.py`。

### 2.5 `uuucli`
- 角色：NXP UUU 工具源码与本地构建目录。
- 负责：USB SDP/Fastboot 传输烧录。
- 可执行文件：`uuucli/build/uuu/uuu`。

### 2.6 `flash_usb_shell`
- 角色：项目烧录与验证编排层（本仓库最常用入口）。
- 负责：自动进烧录模式、调用 uuu、刷后串口验证、批量流程脚本化。
- 说明：已替代旧目录 `tools/imx6ull_flash_serial_framework`。

## 3. 基础使用说明

### 3.1 准备与初始化

```bash
cd /home/ubuntu/imx6ull-pro_linux5.4.47
git submodule update --init --recursive
```

### 3.2 编译系统（Buildroot）

```bash
cd buildroot-2026.02.1
make 100ask_imx6ull-pro_defconfig
make -j"$(nproc)"
```

编译后检查：

```bash
ls -lh output/images/{u-boot-dtb.imx,sdcard.img,zImage}
```

### 3.3 烧录方式1：ROM SDP（`-b emmc_all`）

```bash
cd /home/ubuntu/imx6ull-pro_linux5.4.47
sudo ./uuucli/build/uuu/uuu -v -b emmc_all \
  ./buildroot-2026.02.1/output/images/u-boot-dtb.imx \
  ./buildroot-2026.02.1/output/images/sdcard.img
```

适用：板子在 SDP 模式，或通过 U-Boot `bmode usb` 自动切入 SDP。

### 3.4 烧录方式2：U-Boot Fastboot

先确保目标已进入 `fastboot 0`，再执行：

```bash
cd /home/ubuntu/imx6ull-pro_linux5.4.47
./flash_usb_shell/way2_recovery_flash.sh
```

### 3.5 一键自动流程（推荐）

```bash
cd /home/ubuntu/imx6ull-pro_linux5.4.47
./flash_usb_shell/add_pkg_flash_verify.sh BR2_PACKAGE_HTOP "uname -a; htop -v || true"
```

用途：启用包 -> 编译 -> 自动进 fastboot -> 烧录 -> 串口验证。

## 4. AI 调用操作手册

下面是建议直接发给 AI 助手的任务模板，按场景给出最简步骤。

### 4.1 编译并烧写系统

AI 指令模板：

```text
请在 /home/ubuntu/imx6ull-pro_linux5.4.47 下：
1) make 100ask_imx6ull-pro_defconfig && make -j8
2) 用方式1刷写（uuu -b emmc_all）
3) 串口验证 uname -a 与 rootfs 挂载日志
4) 输出完整执行日志与结论
```

### 4.2 新增一个应用程序（Buildroot 包）

AI 指令模板：

```text
请在 buildroot-2026.02.1 新增一个自定义包 myapp：
1) 创建 package/myapp/{Config.in,myapp.mk,src/...}
2) 接入 package/Config.in 与 100ask_imx6ull-pro_defconfig
3) 编译并验证 /usr/bin/myapp 存在
4) 如需开机自启，放到 board/100ask/imx6ull-pro/rootfs-overlay/etc/init.d/
```

最简人工步骤：
- 新包目录 + `Config.in` + `.mk`
- 在 `package/Config.in` `source` 进去
- 在 defconfig 置 `BR2_PACKAGE_MYAPP=y`
- `make` 后串口验证可执行文件与功能

### 4.3 新增一个驱动模块（Kernel）

AI 指令模板：

```text
请在 linux-imx 中新增/修改驱动模块并接入 Buildroot：
1) 修改对应驱动源码与 Kconfig/Makefile
2) 调整内核配置使模块为 m 或 y
3) 重新编译 Buildroot 镜像
4) 烧录后串口验证 dmesg、lsmod、/sys 节点
```

最简人工步骤：
- 在 `linux-imx` 修改驱动和配置
- 如需固定配置，补到 `board/100ask/imx6ull-pro/linux-fragment.config`
- 重编系统并烧录
- 用串口跑 `dmesg | grep <driver>`、`lsmod`、功能测试命令

### 4.4 只改 U-Boot 启动/升级逻辑

AI 指令模板：

```text
请仅修改 U-Boot 升级入口（bmode/fastboot）并验证：
1) 修改 uboot-imx 对应逻辑
2) Buildroot 重编 u-boot-dtb.imx
3) 执行方式1和方式2刷写链路验证
4) 提供回归风险与回滚建议
```

### 4.5 串口自动化回归

AI 指令模板：

```text
请使用 flash_usb_shell + linux_serial_agent 做无人值守回归：
1) 自动抢占 U-Boot 或 Linux
2) 自动刷写
3) 自动登录并执行校验命令
4) 输出失败点与修复建议
```

## 5. 维护约定

- 路径约定：所有烧录与串口框架脚本统一维护在 `flash_usb_shell`。
- UUU 路径约定：统一使用 `uuucli/build/uuu/uuu`。
- 新增流程文档时，优先更新本 README 与 `flash_usb_shell/FRAMEWORK.md`。
