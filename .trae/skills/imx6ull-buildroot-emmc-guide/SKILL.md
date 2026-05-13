---
name: "imx6ull-buildroot-emmc-guide"
description: "整理 i.MX6ULL 基于 Buildroot 2026.02.1 的完整 eMMC 交付流程。用户需要从源码到编译产物再到 dd/uuu 烧写时调用。"
---

# i.MX6ULL Buildroot eMMC Guide

适用场景：
- 需要基于 Buildroot 2026.02.1 为 i.MX6ULL 生成可启动 eMMC 镜像
- 需要沿用仓库内 `100ask_imx6ull-pro_defconfig` 的在线源码配置
- 需要输出 `dd`、`SDP`、`Fastboot` 三类交付方式

## 1) 目录约定

```bash
WORK=/home/ubuntu/imx6ull-pro_linux5.4.47
BR=$WORK/buildroot-2026.02.1
IMG=$BR/output/images
```

## 2) 使用仓库内 defconfig

- `configs/100ask_imx6ull-pro_defconfig`

关键点：
- U-Boot: `mx6ull_14x14_evk_emmc`
- Kernel DTS: 当前 defconfig 已切回 `imx6ull-14x14-evk`
- RootFS: `ext4` 变体（Buildroot 输出为 `rootfs.ext2` 链接到 `rootfs.ext4`）
- 镜像：`sdcard.img`（可直接写入 eMMC 用户区）
- 源码方式：保持在线仓库引用，不切到本地绝对路径覆盖
- 当前已验证的固定项：
  - `BR2_LINUX_KERNEL_CUSTOM_REPO_URL="https://gitee.com/weidongshan/linux-imx.git"`
  - `BR2_LINUX_KERNEL_CUSTOM_REPO_VERSION="05967a3aaba135f40eee6eaf14ced11c090d32c1"`
  - `BR2_TARGET_UBOOT_CUSTOM_REPO_URL="https://gitee.com/weidongshan/uboot-imx.git"`
  - `BR2_TARGET_UBOOT_CUSTOM_REPO_VERSION="65baaf3fb37946b98d7c85ad5e014f9389d580a4"`
  - `BR2_GLOBAL_PATCH_DIR="board/100ask/imx6ull-pro/patches"`

## 3) 兼容修正（当前仓库必须保留）

- 旧 `linux-imx` 内核在当前主机工具链下，会因 ARM 汇编旧式 `.section ..., #alloc` 语法编译失败。
- 该兼容问题已通过 `board/100ask/imx6ull-pro/patches/linux/` 下的板级补丁处理。
- 维护要求：
  - 不要直接修改 `output/build/linux-*`
  - 统一把兼容修正放回 `board/100ask/imx6ull-pro/patches`

## 4) 编译全流程

```bash
cd $BR
make 100ask_imx6ull-pro_defconfig
make -j8
```

首次构建耗时较长，完成后产物在 `output/images/`。

拉源码连通性检查：

```bash
cd $BR
make source
```

若这里失败，优先检查在线仓库 URL/commit，不要回退成 `local site` 临时绕过。

## 5) 产物检查

```bash
ls -lh $IMG
```

重点文件：
- `u-boot-dtb.imx`
- `zImage`
- `imx6ull-14x14-evk.dtb`（当前默认且实机推荐）
- `imx6ull-14x14-evk-emmc.dtb`（保留对比，不作为当前默认）
- `rootfs.ext2`（链接 `rootfs.ext4`）
- `sdcard.img`

## 5.1) 应用开发架构图

```text
Buildroot package/app
        |
        v
100ask_imx6ull-pro_defconfig
        |
        v
make -> output/images/sdcard.img
        |
        v
board_workflows/select_flash_mode.sh
        |
        +--> app/package/rootfs/overlay --> Fastboot
        |
        +--> kernel/uboot/dtb/system -----> SDP
```

## 5.2) 应用开发流程图

```text
新增或修改应用
      |
      v
更新 package/Config.in 与包目录
      |
      v
defconfig 使能 BR2_PACKAGE_xxx
      |
      v
make 100ask_imx6ull-pro_defconfig && make
      |
      v
确认 target/usr/bin/xxx 与 output/images/sdcard.img
      |
      v
若仅应用层变更 -> Fastboot 烧录
      |
      v
串口验证 which xxx; xxx
```

## 6) eMMC 烧写（dd 方案）

### 8.1 整盘写入（推荐）

```bash
IMG=/home/ubuntu/imx6ull-pro_linux5.4.47/buildroot-2026.02.1/output/images
EMMC_DEV=/dev/mmcblk1   # 按实际修改，务必确认不是系统盘

sudo umount ${EMMC_DEV}p* 2>/dev/null || true
sudo dd if=${IMG}/sdcard.img of=${EMMC_DEV} bs=4M status=progress conv=fsync,notrunc
sync
sudo partprobe ${EMMC_DEV} || true
```

### 8.2 仅更新 U-Boot

```bash
IMG=/home/ubuntu/imx6ull-pro_linux5.4.47/buildroot-2026.02.1/output/images
EMMC_DEV=/dev/mmcblk1

sudo dd if=${IMG}/u-boot-dtb.imx of=${EMMC_DEV} bs=1K seek=1 status=progress conv=fsync,notrunc
sync
```

## 7) eMMC 烧写（uuu 方案）

### 7.1 SDP 直刷整镜像

```bash
cat > emmc_all.uuu <<'EOF'
SDP: boot -f u-boot-dtb.imx
FB: ucmd setenv fastboot_dev mmc
FB: ucmd mmc dev 1
FB: flash -raw2sparse all sdcard.img
FB: done
EOF

cd /home/ubuntu/imx6ull-pro_linux5.4.47/buildroot-2026.02.1/output/images
uuu -V emmc_all.uuu
```

### 7.2 Fastboot 开发链路

适用于 `app/package/rootfs/overlay/userland/service` 变更：

```bash
cd /home/ubuntu/imx6ull-pro_linux5.4.47
CHANGE_SCOPE=package ./board_workflows/flash_fastboot_deploy.sh
```

若只是启用一个 Buildroot 包并验证：

```bash
cd /home/ubuntu/imx6ull-pro_linux5.4.47
./flash_usb_shell/add_pkg_flash_verify.sh BR2_PACKAGE_HELLO_APP "which hello; hello"
```

### 7.3 UMS 转出块设备再 dd

```bash
cat > emmc_ums.uuu <<'EOF'
SDP: boot -f u-boot-dtb.imx
FB: ucmd mmc dev 1
FB: ucmd ums 0 mmc 1
EOF

cd /home/ubuntu/imx6ull-pro_linux5.4.47/buildroot-2026.02.1/output/images
uuu -V emmc_ums.uuu
# 主机出现 /dev/sdX 后执行:
# sudo dd if=sdcard.img of=/dev/sdX bs=4M status=progress conv=fsync,notrunc
# sync
```

## 8) 现场前提与排障

- 若在虚拟机中运行：
  - USB 转串口设备要先透传到当前 Linux 环境，串口节点应表现为 `ttyUSB*` 或 `ttyACM*`
  - 板卡 USB 烧录口也要透传，否则 `uuu -lsusb` 看不到目标设备
- 若自动流程报 `no serial port found`：
  - 先查 `/dev/ttyUSB* /dev/ttyACM*`
  - 只看到宿主机 `ttyS*` 通常表示 USB 转串口没有透传成功

## 9) 启动验证

- 能进入 U-Boot
- `mmc list` 能看到 eMMC
- `zImage` + `imx6ull-14x14-evk.dtb` 可正常启动
- 根文件系统可挂载并进入 shell
