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
│ board_workflows                                                      │
│  ├─ auto_flash_and_serial.sh    (通用自动编排入口)                   │
│  └─ add_pkg_flash_verify.sh     (加包->编译->刷写->验证)             │
│          │                                     │                      │
│          │ serial CLI                          │ usb CLI              │
│          ▼                                     ▼                      │
│ linux_serial_agent                     flash_usb_shell                │
│  ├─ serial_agent_cli.py               ├─ usb_flash_cli.py            │
│  ├─ serial_agent/                     ├─ usb_flash/                  │
│  └─ trae_serial_terminal_go           └─ *.uuu                       │
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
- 角色：独立串口能力模块。
- 负责：串口枚举、参数管理、缓冲收发、U-Boot 串口交互、自动登录校验。
- 统一接口：`linux_serial_agent/serial_agent_cli.py`。

### 2.5 `uuucli`
- 角色：NXP UUU 工具源码与本地构建目录。
- 负责：USB SDP/Fastboot 传输烧录。
- 可执行文件：`uuucli/build/uuu/uuu`。

### 2.6 `flash_usb_shell`
- 角色：纯 USB 烧录模块。
- 负责：`uuu` 调用、USB 枚举检测、`.uuu` 脚本执行与进度输出。
- 统一接口：`flash_usb_shell/usb_flash_cli.py`。

### 2.7 `board_workflows`
- 角色：上层编排层。
- 负责：只通过串口 CLI 与 USB CLI 组合原有流程，不嵌入底层协议实现。
- 兼容入口：原 `flash_usb_shell/*.sh` 保留为薄包装，转发到该目录。

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

### 3.6 模块依赖图

- 详见 `MODULE_DEPENDENCY_GRAPH.md`
- 约束：
  - `linux_serial_agent` 不调用 USB 烧录接口
  - `flash_usb_shell` 不依赖串口实现
  - `board_workflows` 只通过两侧 CLI 抽象接口交互

## 4. 全自动 AI 应用开发架构与流程

本仓库的目标不是只保存源码，而是把“需求 -> 编码 -> 编译 -> 烧录 -> 串口验证 -> 结果反馈”做成 AI 可以连续执行的闭环。用户只需要描述目标应用或系统能力，AI 按固定软件分层调用脚本和工具完成开发、集成和实机验证。

### 4.1 软件架构图

```text
┌──────────────────────────────────────────────────────────────────────┐
│                         用户 / 产品需求                              │
│  例：新增一个串口采集应用、加入 LVGL 界面、修改驱动、刷机后验证       │
└───────────────────────────────┬──────────────────────────────────────┘
                                │ 自然语言任务
                                ▼
┌──────────────────────────────────────────────────────────────────────┐
│                         AI 开发编排层                                │
│  - 读取 README / skills / 约定文档                                    │
│  - 判断任务类型：应用 / RootFS / Kernel / U-Boot / 烧录回归           │
│  - 生成修改计划并落地代码                                             │
│  - 选择最小必要验证路径                                               │
└───────────────┬───────────────────────────────┬──────────────────────┘
                │                               │
                ▼                               ▼
┌──────────────────────────────┐   ┌───────────────────────────────────┐
│ Buildroot 系统集成层          │   │ 板级自动化工作流层                 │
│ buildroot-2026.02.1           │   │ board_workflows                    │
│ - package/<app>/              │   │ - add_pkg_flash_verify.sh          │
│ - configs/*_defconfig         │   │ - flash_fastboot_deploy.sh         │
│ - rootfs-overlay/             │   │ - flash_sdp_full.sh                │
│ - linux-fragment.config       │   │ - select_flash_mode.sh             │
└───────────────┬──────────────┘   └──────────────┬────────────────────┘
                │                                 │
                ▼                                 ▼
┌──────────────────────────────┐   ┌───────────────────────────────────┐
│ 源码与镜像产物层              │   │ 设备连接抽象层                     │
│ - uboot-imx                   │   │ linux_serial_agent                 │
│ - linux-imx                   │   │ - serial_agent_cli.py              │
│ - output/images/              │   │ - 自动登录 / U-Boot 抢占 / 命令发送│
│   u-boot-dtb.imx              │   │ flash_usb_shell                    │
│   zImage / dtb / sdcard.img   │   │ - usb_flash_cli.py                 │
└───────────────┬──────────────┘   │ - UUU 脚本生成与执行               │
                │                  └──────────────┬────────────────────┘
                └──────────────────┬──────────────┘
                                   ▼
┌──────────────────────────────────────────────────────────────────────┐
│                         i.MX6ULL Pro 实机                            │
│  U-Boot fastboot / ROM SDP / Linux shell / 应用进程 / dmesg / sysfs   │
└──────────────────────────────────────────────────────────────────────┘
```

### 4.2 AI 自动开发闭环

标准闭环建议按下面顺序执行：

1. 明确目标：说明要新增的应用、驱动、服务、UI 或启动行为。
2. 定位层级：AI 判断改动属于 Buildroot 包、RootFS overlay、Kernel、U-Boot，还是纯脚本流程。
3. 修改代码：按仓库既有目录和接口实现，不绕过 `board_workflows`、`linux_serial_agent`、`flash_usb_shell` 的抽象边界。
4. 编译镜像：执行 `make 100ask_imx6ull-pro_defconfig && make -j$(nproc)`。
5. 选择烧录链路：
   - 应用、包、RootFS、服务类改动：优先走 Fastboot 开发刷写。
   - Kernel、DTB、U-Boot、全系统类改动：优先走 SDP 或完整系统刷写。
6. 实机验证：串口登录后执行明确的检查命令，如 `uname -a`、`ls -l /usr/bin/<app>`、`pidof <app>`、`dmesg | grep <driver>`。
7. 输出结论：说明改了什么、跑了什么、通过了什么、没有覆盖什么。

### 4.3 常用自动化入口

#### 新增或验证 Buildroot 应用包

```bash
cd /home/ubuntu/imx6ull-pro_linux5.4.47
./flash_usb_shell/add_pkg_flash_verify.sh \
  BR2_PACKAGE_LVGL9_DEMO \
  "uname -a; ls -l /usr/bin/lvgl9-demo; pidof lvgl9-demo || true"
```

该入口会完成：
- 更新 defconfig
- 编译 Buildroot
- 自动进入 Fastboot
- UUU 刷写 eMMC
- 串口登录执行验证命令

#### 已有镜像的 Fastboot 开发刷写

```bash
cd /home/ubuntu/imx6ull-pro_linux5.4.47
SERIAL_PORT=/dev/ttyACM0 \
CHECK_CMD="uname -a; mount; ps" \
CHANGE_SCOPE=package \
./board_workflows/flash_fastboot_deploy.sh
```

#### 全系统 SDP 刷写与串口验证

```bash
cd /home/ubuntu/imx6ull-pro_linux5.4.47
SERIAL_PORT=/dev/ttyACM0 \
CHECK_CMD="uname -a; dmesg | tail -n 80" \
CHANGE_SCOPE=system \
./board_workflows/flash_sdp_full.sh
```

### 4.4 推荐提问方式

向 AI 提需求时，最好同时给出 5 类信息：目标、修改范围、启动方式、验证命令、输出要求。

通用模板：

```text
请在 /home/ubuntu/imx6ull-pro_linux5.4.47 完成一个全自动闭环任务：
目标：<要实现的功能>
范围：<应用包 / RootFS overlay / Kernel 驱动 / U-Boot / 烧录脚本>
约束：<不要改哪些模块，是否需要开机自启，是否必须兼容无密码 root>
验证：<烧录后在串口执行哪些命令判断成功>
输出：<列出修改文件、编译命令、烧录方式、串口验证结果和风险>
```

新增应用推荐问法：

```text
请新增一个 Buildroot 应用 myapp：
1) 在 package/myapp 下实现源码、Config.in、myapp.mk
2) 接入 package/Config.in 和 100ask_imx6ull-pro_defconfig
3) 编译并通过 Fastboot 自动刷写
4) 串口验证：uname -a; ls -l /usr/bin/myapp; myapp --version || true
5) 最后输出完整闭环结果
```

新增开机服务推荐问法：

```text
请把 myapp 做成开机自启服务：
1) 添加 rootfs-overlay/etc/init.d/S99myapp
2) 确认脚本权限为 0755
3) 重新编译、刷写、串口验证
4) 验证命令：ls -l /etc/init.d/S99myapp; pidof myapp || true; tail -n 40 /var/log/myapp.log || true
```

驱动或设备树推荐问法：

```text
请修改 linux-imx 中的 <driver/dts> 并接入 Buildroot：
1) 修改源码、Kconfig、Makefile 或 dts
2) 如需固定内核配置，更新 board/100ask/imx6ull-pro/linux-fragment.config
3) 编译完整镜像并走系统级烧录
4) 串口验证：dmesg | grep <关键字>; lsmod; cat /sys/<节点>
5) 输出失败时的定位建议
```

### 4.5 结果验收格式

建议要求 AI 最终按下面格式输出，方便复盘：

```text
结论：通过 / 未通过
修改文件：
- <file1>
- <file2>

执行命令：
- make 100ask_imx6ull-pro_defconfig
- make -j<N>
- <flash command>

实机验证：
- 串口：/dev/ttyACM0, 115200
- 登录：root
- 命令：<CHECK_CMD>
- 关键输出：<uname / pid / dmesg / ls 结果>

风险与未覆盖：
- <没有测试的硬件外设或边界>
- <需要人工确认的现象>
```

## 5. AI 调用操作手册

下面是建议直接发给 AI 助手的任务模板，按场景给出最简步骤。

### 5.1 编译并烧写系统

AI 指令模板：

```text
请在 /home/ubuntu/imx6ull-pro_linux5.4.47 下：
1) make 100ask_imx6ull-pro_defconfig && make -j8
2) 用方式1刷写（uuu -b emmc_all）
3) 串口验证 uname -a 与 rootfs 挂载日志
4) 输出完整执行日志与结论
```

### 5.2 新增一个应用程序（Buildroot 包）

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

### 5.3 新增一个驱动模块（Kernel）

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

### 5.4 只改 U-Boot 启动/升级逻辑

AI 指令模板：

```text
请仅修改 U-Boot 升级入口（bmode/fastboot）并验证：
1) 修改 uboot-imx 对应逻辑
2) Buildroot 重编 u-boot-dtb.imx
3) 执行方式1和方式2刷写链路验证
4) 提供回归风险与回滚建议
```

### 5.5 串口自动化回归

AI 指令模板：

```text
请使用 flash_usb_shell + linux_serial_agent 做无人值守回归：
1) 自动抢占 U-Boot 或 Linux
2) 自动刷写
3) 自动登录并执行校验命令
4) 输出失败点与修复建议
```

## 6. 维护约定

- 路径约定：所有烧录与串口框架脚本统一维护在 `flash_usb_shell`。
- UUU 路径约定：统一使用 `uuucli/build/uuu/uuu`。
- 新增流程文档时，优先更新本 README 与 `flash_usb_shell/FRAMEWORK.md`。
