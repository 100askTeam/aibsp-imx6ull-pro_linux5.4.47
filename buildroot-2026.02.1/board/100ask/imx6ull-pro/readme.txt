100ask i.MX6ULL Pro (eMMC) - Buildroot integration notes
=========================================================

This board configuration is based on i.MX6ULL EVK style support in Buildroot,
but uses local U-Boot/Linux sources prepared in this workspace.

Defconfig name
--------------

  100ask_imx6ull-pro_defconfig

Main points
-----------

- U-Boot defconfig: mx6ull_14x14_evk_emmc
- Kernel defconfig: imx_v7
- Kernel DTB: imx6ull-14x14-evk-emmc.dtb
- Rootfs image: ext4 (generated as rootfs.ext2 with ext4 options)
- Final disk image: sdcard.img (can be written to eMMC as a raw image)

Default source input
--------------------

This defconfig consumes the local tarballs:

- /home/ubuntu/imx6ull-pro_linux5.4.47/sources/uboot-imx-100ask-local.tar.gz
- /home/ubuntu/imx6ull-pro_linux5.4.47/sources/linux-imx-100ask-local.tar.gz

Re-generate tarballs after local source changes:

  cd /home/ubuntu/imx6ull-pro_linux5.4.47
  tar --exclude-vcs -czf sources/uboot-imx-100ask-local.tar.gz uboot-imx
  tar --exclude-vcs -czf sources/linux-imx-100ask-local.tar.gz linux-imx

Optional: develop directly from source tree
-------------------------------------------

Instead of tarballs, you can use Buildroot override file:

1. Copy board/100ask/imx6ull-pro/local.mk.example to local.mk
2. Run:
     make 100ask_imx6ull-pro_defconfig
     make

Output artifacts
----------------

After a successful build:

- output/images/u-boot-dtb.imx
- output/images/zImage
- output/images/imx6ull-14x14-evk-emmc.dtb
- output/images/rootfs.ext2
- output/images/sdcard.img

For eMMC, program sdcard.img to the eMMC user area, or separately deploy
u-boot-dtb.imx + zImage + dtb + rootfs according to your boot flow.
