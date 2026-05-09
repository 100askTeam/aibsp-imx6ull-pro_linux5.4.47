################################################################################
#
# libunistring
#
################################################################################

LIBUNISTRING_VERSION = 1.4.2
LIBUNISTRING_SITE = $(BR2_GNU_MIRROR)/libunistring
LIBUNISTRING_SOURCE = libunistring-$(LIBUNISTRING_VERSION).tar.xz
LIBUNISTRING_INSTALL_STAGING = YES
LIBUNISTRING_LICENSE = LGPL-3.0+ or GPL-2.0
LIBUNISTRING_LICENSE_FILES = COPYING COPYING.LIB
LIBUNISTRING_CPE_ID_VENDOR = gnu

# Work around host-libunistring test-link failures on some host toolchains
# by restricting host build/install to the library subtree.
HOST_LIBUNISTRING_MAKE_OPTS = SUBDIRS=lib
HOST_LIBUNISTRING_INSTALL_OPTS = SUBDIRS=lib install

define HOST_LIBUNISTRING_FIXUP_PKGCONFIG
	mkdir -p $(HOST_DIR)/lib/pkgconfig
	printf '%s\n' \
		'prefix=$(HOST_DIR)' \
		'exec_prefix=$${prefix}' \
		'libdir=$${exec_prefix}/lib' \
		'includedir=$${prefix}/include' \
		'' \
		'Name: libunistring' \
		'Description: Unicode string library' \
		'Version: $(LIBUNISTRING_VERSION)' \
		'Libs: -L$${libdir} -lunistring' \
		'Cflags: -I$${includedir}' \
		> $(HOST_DIR)/lib/pkgconfig/libunistring.pc
endef
HOST_LIBUNISTRING_POST_INSTALL_HOOKS += HOST_LIBUNISTRING_FIXUP_PKGCONFIG

$(eval $(autotools-package))
$(eval $(host-autotools-package))
