################################################################################
#
# mqtt-demo
#
################################################################################

MQTT_DEMO_VERSION = 1.0
MQTT_DEMO_SITE = $(MQTT_DEMO_PKGDIR)/src
MQTT_DEMO_SITE_METHOD = local
MQTT_DEMO_LICENSE = MIT
MQTT_DEMO_LICENSE_FILES = mqtt_demo.c
MQTT_DEMO_DEPENDENCIES = mosquitto

define MQTT_DEMO_BUILD_CMDS
	$(TARGET_CC) $(TARGET_CFLAGS) $(TARGET_LDFLAGS) \
		$(@D)/mqtt_demo.c -o $(@D)/mqtt-demo -lmosquitto -lpthread
endef

define MQTT_DEMO_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/mqtt-demo $(TARGET_DIR)/usr/bin/mqtt-demo
endef

$(eval $(generic-package))
