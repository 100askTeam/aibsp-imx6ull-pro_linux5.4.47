################################################################################
#
# lvgl9-demo
#
################################################################################

LVGL9_DEMO_VERSION = 9.2.2
LVGL9_DEMO_SITE = $(call github,lvgl,lvgl,v$(LVGL9_DEMO_VERSION))
LVGL9_DEMO_LICENSE = MIT
LVGL9_DEMO_LICENSE_FILES = LICENCE.txt

define LVGL9_DEMO_BUILD_CMDS
	SRCS="$$(find $(@D)/src -name '*.c' -print)"; \
	$(TARGET_CC) $(TARGET_CFLAGS) -O2 \
		-DLV_CONF_PATH=lv_conf.h \
		-DLV_USE_LINUX_FBDEV=1 \
		-DLV_USE_EVDEV=1 \
		-DLV_COLOR_DEPTH=16 \
		-I$(@D) \
		-I$(@D)/src \
		-I$(LVGL9_DEMO_PKGDIR)/src \
		$$SRCS \
		$(LVGL9_DEMO_PKGDIR)/src/lvgl9_preview_ui.c \
		$(LVGL9_DEMO_PKGDIR)/src/lvgl9_demo_main.c \
		-o $(@D)/lvgl9-demo \
		-lm -lpthread -lrt
endef

define LVGL9_DEMO_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/lvgl9-demo $(TARGET_DIR)/usr/bin/lvgl9-demo
endef

$(eval $(generic-package))
