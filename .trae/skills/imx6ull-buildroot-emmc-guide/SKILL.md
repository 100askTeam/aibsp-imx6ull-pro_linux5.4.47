---
name: "imx6ull-buildroot-emmc-guide"
description: "整理 i.MX6ULL 基于 Buildroot 2026.02.1 的完整 eMMC 交付流程。用户需要从源码到编译产物再到 dd/uuu 烧写时调用。"
---

# i.MX6ULL Buildroot eMMC Guide

适用场景：
- 需要基于 Buildroot 2026.02.1 为 i.MX6ULL 生成可启动 eMMC 镜像
- 需要复用本地 `uboot-imx` + `linux-imx` 源码
- 需要输出 `dd` 与 `uuu` 两套烧写方法

## 1) 目录约定

```bash
WORK=/home/ubuntu/imx6ull-pro_linux5.4.47
BR=$WORK/buildroot-2026.02.1
IMG=$BR/output/images
```

## 2) 准备源码与 Buildroot

```bash
cd $WORK

# U-Boot / Linux
git clone https://gitee.com/weidongshan/uboot-imx
git clone https://gitee.com/weidongshan/linux-imx

# Buildroot
wget -c https://buildroot.org/downloads/buildroot-2026.02.1.tar.gz
tar -xf buildroot-2026.02.1.tar.gz
```

## 3) 生成本地源码 tarball（供 Buildroot 使用）

```bash
mkdir -p $WORK/sources
cd $WORK
tar --exclude-vcs --exclude='./sources/*' -czf sources/uboot-imx-100ask-local.tar.gz uboot-imx
tar --exclude-vcs --exclude='./sources/*' -czf sources/linux-imx-100ask-local.tar.gz linux-imx
```

## 4) 使用板级 defconfig

使用：
- `configs/100ask_imx6ull-pro_defconfig`

关键点：
- U-Boot: `mx6ull_14x14_evk_emmc`
- Kernel DTS: 默认可用 `imx6ull-14x14-evk-emmc`
- RootFS: `ext4`（Buildroot 输出为 `rootfs.ext2` + ext4 特性）
- 镜像：`sdcard.img`（可直接写入 eMMC 用户区）

### 实机校正（当前项目必须关注）

- 当前 100ask i.MX6ULL Pro 实测中，`imx6ull-14x14-evk-emmc.dtb` 可能触发 eMMC 初始化不稳定（`mmc1: error -110`）。
- 实机闭环采用：`imx6ull-14x14-evk.dtb` + `usdhc2` 保守参数（4bit、`no-1-8-v`、50MHz）。
- 判据：启动日志出现 `mmcblk1: ... p1 p2`、`EXT4-fs ... mounted`、`buildroot login`。

## 5) 兼容修正（Buildroot 2026.02.1 + 当前主机）

若遇到主机包构建问题，确保以下修正存在：
- `package/libunistring/libunistring.mk`
  - host 仅构建/安装 `lib` 子目录
  - 安装后补 `output/host/lib/pkgconfig/libunistring.pc`
- `package/gnutls/gnutls.mk`
  - host gnutls 使用 `--with-included-unistring`
- `board/100ask/imx6ull-pro/linux-fragment.config`
  - 关闭 `ATA/AHCI`
  - 关闭 `MXC_GPU_VIV`

## 6) 编译全流程

```bash
cd $BR
make 100ask_imx6ull-pro_defconfig
make -j8
```

首次构建耗时较长，完成后产物在 `output/images/`。

## 7) 产物检查

```bash
ls -lh $IMG
```

重点文件：
- `u-boot-dtb.imx`
- `zImage`
- `imx6ull-14x14-evk-emmc.dtb`（默认）
- `imx6ull-14x14-evk.dtb`（当前实机推荐）
- `rootfs.ext2`（链接 `rootfs.ext4`）
- `sdcard.img`

## 8) eMMC 烧写（dd 方案）

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

## 9) eMMC 烧写（uuu 方案）

### 9.1 fastboot 直刷整镜像

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

### 9.2 UMS 转出块设备再 dd

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

## 10) 启动验证

- 能进入 U-Boot
- `mmc list` 能看到 eMMC
- `zImage` + `imx6ull-14x14-evk-emmc.dtb` 可正常启动
- 根文件系统可挂载并进入 shell
