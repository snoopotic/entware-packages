#
# Copyright (C) 2006-2016 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=udpxy
PKG_VERSION:=1.0-24.1
PKG_RELEASE:=1

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://codeload.github.com/pcherenkov/udpxy/tar.gz/$(PKG_VERSION)?
PKG_HASH:=27e5d3d2bae29522354d1505a3cc931c96953846d68eeb25bb99fe9b0cb6cbe0

PKG_MAINTAINER:=Álvaro Fernández Rojas <noltari@gmail.com>
PKG_LICENSE:=GPL-3.0-or-later
PKG_LICENSE_FILES:=chipmunk/gpl.txt

PKG_INSTALL:=1
PKG_BUILD_PARALLEL:=1

include $(INCLUDE_DIR)/package.mk

MAKE_PATH:=chipmunk

define Package/udpxy
  SECTION:=net
  CATEGORY:=Network
  TITLE:=Convert UDP IPTV streams into HTTP streams
  URL:=https://github.com/pcherenkov/udpxy
endef

define Package/udpxy/description
	udproxy makes it possible to convert UDP IPTV streams into HTTP
	streams which can be viewed even over WLANs. HTTP streams do
	not generate huge amounts of multicast traffic, so a sd stream
	only takes about 300k. Interesting for peoply who have IPTV at
	home and do not want to rent multiple decoders from their
	provider but just use their own streaming client (for example
	popcornhour/mediatomb/vlc).
endef

MAKE_FLAGS += \
	INSTALLROOT="$(PKG_INSTALL_DIR)/opt" \
	ALL_CFLAGS="$(TARGET_CFLAGS) $(TARGET_CPPFLAGS)"

define Package/udpxy/install
	$(INSTALL_DIR) $(1)/opt/etc/init.d
	$(INSTALL_BIN) ./files/S29udpxy $(1)/opt/etc/init.d/
	$(INSTALL_DIR) $(1)/opt/bin
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)/opt/bin/udpxy $(1)/opt/bin/
	ln -sf udpxy $(1)/opt/bin/udpxrec
endef

$(eval $(call BuildPackage,udpxy))
