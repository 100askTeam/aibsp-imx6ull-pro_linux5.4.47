---
name: "imx6ull-build-guide"
description: "整理 i.MX6ULL U-Boot/Kernel 编译流程。用户需要从零拉源码、配置交叉编译环境、编译 zImage/dtb/u-boot 并确认产物用途时调用。"
---

# i.MX6ULL Build Guide

适用于 i.MX6ULL 开发流程的标准化步骤，覆盖：
- 获取源码
- 配置交叉编译环境
- 编译 U-Boot
- 编译 Linux 内核与设备树
- 产物使用与烧写要点

## 1. 获取源码

```bash
# 建议工作目录
mkdir -p ~/imx6ull-pro_linux5.4.47
cd ~/imx6ull-pro_linux5.4.47

# U-Boot
git clone https://gitee.com/weidongshan/uboot-imx

# Linux Kernel
git clone https://gitee.com/weidongshan/linux-imx
```

## 2. 交叉编译环境

### 2.1 推荐工具链

- 优先使用厂商常见工具链：`arm-none-linux-gnueabihf-`（如 gcc 9.2）
- 若本机没有该工具链，可使用系统包：

```bash
sudo apt-get update
sudo apt-get install -y \
  gcc-arm-linux-gnueabihf gcc-9-arm-linux-gnueabihf \
  make bc bison flex libssl-dev
```

### 2.2 环境变量

```bash
export ARCH=arm
export CROSS_COMPILE=arm-linux-gnueabihf-
```

如果你本地是厂商工具链路径，也可以用：

```bash
export ARCH=arm
export CROSS_COMPILE=arm-none-linux-gnueabihf-
export PATH=$PATH:/path/to/gcc-arm-9.2/bin
```

## 3. 编译 U-Boot（eMMC 启动）

```bash
cd ~/imx6ull-pro_linux5.4.47/uboot-imx
export ARCH=arm
export CROSS_COMPILE=arm-linux-gnueabihf-

make mx6ull_14x14_evk_emmc_defconfig
make -j8
```

关键产物：
- `u-boot-dtb.imx`：烧写镜像（常用）
- `u-boot.bin` / `u-boot-dtb.bin`：调试或二次处理可用

## 4. 编译 Linux 内核与设备树

```bash
cd ~/imx6ull-pro_linux5.4.47/linux-imx
export ARCH=arm
export CROSS_COMPILE=arm-linux-gnueabihf-

# 推荐配置
make imx_v7_defconfig

# 内核镜像
make zImage -j8 CC=arm-linux-gnueabihf-gcc-9 KCFLAGS="-march=armv7-a -mfpu=vfpv3-d16"

# 设备树
make dtbs -j8 CC=arm-linux-gnueabihf-gcc-9 KCFLAGS="-march=armv7-a -mfpu=vfpv3-d16"
```

关键产物：
- `arch/arm/boot/zImage`
- `arch/arm/boot/dts/imx6ull-14x14-evk-emmc.dtb`（eMMC 板型常用）

## 5. 产物如何使用

典型启动文件组合：
- 引导：`u-boot-dtb.imx`
- 内核：`zImage`
- 设备树：对应板型 `*.dtb`
- 根文件系统：ext4 分区或 NFS

常见部署方式：
- U-Boot 烧写到 eMMC 启动区域（或 SD 卡起始扇区）
- `zImage` 与 `dtb` 放到启动分区（如 FAT/ext4 的 `/boot`）
- U-Boot 中通过 `bootz` 启动，例如：

```bash
load mmc 0:1 ${loadaddr} zImage
load mmc 0:1 ${fdt_addr} imx6ull-14x14-evk-emmc.dtb
bootz ${loadaddr} - ${fdt_addr}
```

## 6. 常见问题

- DNS 解析失败：先修复网络/DNS，再执行 `git clone` 或 `apt-get`
- 旧内核在新汇编器报 `.section ..., #alloc`：需改为 GNU as 新语法（如 `"a"` 或 `"ax"`）
- 汇编指令不支持（`isb/cpsid/dmb`）：检查工具链版本与编译参数，必要时使用 gcc-9 并追加 `KCFLAGS`

## 7. 验证清单

- U-Boot：`ls -lh u-boot-dtb.imx`
- Kernel：`ls -lh arch/arm/boot/zImage`
- DTB：`ls -lh arch/arm/boot/dts/imx6ull-14x14-evk-emmc.dtb`

全部存在且大小正常，即可进入烧写与上板验证阶段。
