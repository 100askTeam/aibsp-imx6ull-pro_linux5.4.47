################################################################################
#
# hello-app
#
################################################################################

HELLO_APP_VERSION = 1.0
HELLO_APP_SITE = $(HELLO_APP_PKGDIR)/src
HELLO_APP_SITE_METHOD = local
HELLO_APP_LICENSE = MIT
HELLO_APP_LICENSE_FILES = hello.c

define HELLO_APP_BUILD_CMDS
	$(TARGET_CC) $(TARGET_CFLAGS) $(TARGET_LDFLAGS) \
		$(@D)/hello.c -o $(@D)/hello
endef

define HELLO_APP_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/hello $(TARGET_DIR)/usr/bin/hello
endef

$(eval $(generic-package))
