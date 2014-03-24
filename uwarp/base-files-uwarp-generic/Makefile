#
# Copyright (C) 2007-2013 OpenWrt.org
# Copyright (C) 2010 Vertical Communications
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/version.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=base-files-uwarp-generic
PKG_RELEASE:=1

PKG_FILE_DEPENDS:=$(PLATFORM_DIR)/ $(GENERIC_PLATFORM_DIR)/base-files-uwarp-generic/
PKG_BUILD_DEPENDS:=opkg/host

include $(INCLUDE_DIR)/package.mk

define Package/base-files-uwarp-generic
  SECTION:=base
  CATEGORY:=Base system
  DEPENDS:=
  TITLE:=Base files for the uWARP board
  VERSION:=$(PKG_RELEASE)-$(REVISION)
endef


define Package/base-files-uwarp-generic/description
 This package contains a base filesystem and system scripts for OpenWrt.
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
endef

define Build/Compile/Default

endef
Build/Compile = $(Build/Compile/Default)

define Package/base-files-uwarp-generic/install
	$(CP) ./files/* $(1)/
endef

$(eval $(call BuildPackage,base-files-uwarp-generic))
