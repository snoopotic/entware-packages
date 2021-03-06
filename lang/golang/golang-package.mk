#
# Copyright (C) 2018 Jeffery To
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

ifeq ($(origin GO_INCLUDE_DIR),undefined)
  GO_INCLUDE_DIR:=$(dir $(lastword $(MAKEFILE_LIST)))
endif

include $(GO_INCLUDE_DIR)/golang-values.mk


# Variables (all optional, except GO_PKG) to be set in package
# Makefiles:
#
# GO_PKG (required) - name of Go package
#
#   Go name of the package.
#
#   e.g. GO_PKG:=golang.org/x/text
#
#
# GO_PKG_INSTALL_EXTRA - list of regular expressions, default empty
#
#   Additional files/directories to install. By default, only these
#   files are installed:
#
#   * Files with one of these extensions:
#     .go, .c, .cc, .cpp, .h, .hh, .hpp, .proto, .s
#
#   * Files in any 'testdata' directory
#
#   * go.mod and go.sum, in any directory
#
#   e.g. GO_PKG_INSTALL_EXTRA:=example.toml marshal_test.toml
#
#
# GO_PKG_INSTALL_ALL - boolean (0 or 1), default false
#
#   If true, install all files regardless of extension or directory.
#
#   e.g. GO_PKG_INSTALL_ALL:=1
#
#
# GO_PKG_SOURCE_ONLY - boolean (0 or 1), default false
#
#   If true, 'go install' will not be called. If the package does not
#   (or should not) build any binaries, then specifying this option will
#   save build time.
#
#   e.g. GO_PKG_SOURCE_ONLY:=1
#
#
# GO_PKG_BUILD_PKG - list of build targets, default GO_PKG/...
#
#   Build targets for compiling this Go package, i.e. arguments passed
#   to 'go install'
#
#   e.g. GO_PKG_BUILD_PKG:=github.com/debian/ratt/cmd/...
#
#
# GO_PKG_EXCLUDES - list of regular expressions, default empty
#
#   Patterns to exclude from the build targets expanded from
#   GO_PKG_BUILD_PKG.
#
#   e.g. GO_PKG_EXCLUDES:=examples/
#
#
# GO_PKG_GO_GENERATE - boolean (0 or 1), default false
#
#   If true, 'go generate' will be called on all build targets (as
#   determined by GO_PKG_BUILD_PKG and GO_PKG_EXCLUDES). This is usually
#   not necessary.
#
#   e.g. GO_PKG_GO_GENERATE:=1
#
#
# GO_PKG_GCFLAGS - list of arguments, default empty
#
#   Additional go tool compile arguments to use when building targets.
#
#   e.g. GO_PKG_GCFLAGS:=-N -l
#
#
# GO_PKG_LDFLAGS - list of arguments, default empty
#
#   Additional go tool link arguments to use when building targets.
#
#   Note that the OpenWrt build system has an option to strip binaries
#   (enabled by default), so -s (Omit the symbol table and debug
#   information) and -w (Omit the DWARF symbol table) flags are not
#   necessary.
#
#   e.g. GO_PKG_LDFLAGS:=-r dir1:dir2 -u
#
#
# GO_PKG_LDFLAGS_X - list of string variable definitions, default empty
#
#   Each definition will be passed as the parameter to the -X go tool
#   link argument, i.e. -ldflags "-X importpath.name=value"
#
#   e.g. GO_PKG_LDFLAGS_X:=main.Version=$(PKG_VERSION) main.BuildStamp=$(SOURCE_DATE_EPOCH)

# Credit for this package build process (GoPackage/Build/Configure and
# GoPackage/Build/Compile) belong to Debian's dh-golang completely.
# https://salsa.debian.org/go-team/packages/dh-golang


# for building packages, not user code
GO_PKG_PATH:=/opt/share/gocode

GO_PKG_BUILD_PKG?=$(strip $(GO_PKG))/...

GO_PKG_WORK_DIR_NAME:=.go_work
GO_PKG_WORK_DIR:=$(PKG_BUILD_DIR)/$(GO_PKG_WORK_DIR_NAME)

GO_PKG_BUILD_DIR:=$(GO_PKG_WORK_DIR)/build
GO_PKG_CACHE_DIR:=$(GO_PKG_WORK_DIR)/cache

GO_PKG_BUILD_BIN_DIR:=$(GO_PKG_BUILD_DIR)/bin$(if $(GO_HOST_TARGET_DIFFERENT),/$(GO_OS_ARCH))

GO_PKG_BUILD_DEPENDS_SRC:=$(STAGING_DIR)$(GO_PKG_PATH)/src

ifdef CONFIG_PKG_ASLR_PIE_ALL
  ifeq ($(strip $(PKG_ASLR_PIE)),1)
    ifeq ($(GO_TARGET_PIE_SUPPORTED),1)
      GO_PKG_ENABLE_PIE:=1
    else
      $(warning PIE buildmode is not supported for $(GO_OS)/$(GO_ARCH))
    endif
  endif
endif

ifdef CONFIG_PKG_ASLR_PIE_REGULAR
  ifeq ($(strip $(PKG_ASLR_PIE_REGULAR)),1)
    ifeq ($(GO_TARGET_PIE_SUPPORTED),1)
      GO_PKG_ENABLE_PIE:=1
    else
      $(warning PIE buildmode is not supported for $(GO_OS)/$(GO_ARCH))
    endif
  endif
endif

# sstrip causes corrupted section header size
ifneq ($(CONFIG_USE_SSTRIP),)
  ifneq ($(CONFIG_DEBUG),)
    GO_PKG_STRIP_ARGS:=--strip-unneeded --remove-section=.comment --remove-section=.note
  else
    GO_PKG_STRIP_ARGS:=--strip-all
  endif
  STRIP:=$(TARGET_CROSS)strip $(GO_PKG_STRIP_ARGS)
endif

define GoPackage/GoSubMenu
  SUBMENU:=Go
  SECTION:=lang
  CATEGORY:=Languages
endef

GO_PKG_TARGET_VARS= \
	GOOS=$(GO_OS) \
	GOARCH=$(GO_ARCH) \
	GO386=$(GO_386) \
	GOARM=$(GO_ARM) \
	GOMIPS=$(GO_MIPS) \
	GOMIPS64=$(GO_MIPS64) \
	CGO_ENABLED=1 \
	CC=$(TARGET_CC) \
	CXX=$(TARGET_CXX) \
	CGO_CFLAGS="$(filter-out $(GO_CFLAGS_TO_REMOVE),$(TARGET_CFLAGS))" \
	CGO_CPPFLAGS="$(TARGET_CPPFLAGS)" \
	CGO_CXXFLAGS="$(filter-out $(GO_CFLAGS_TO_REMOVE),$(TARGET_CXXFLAGS))" \
	CGO_LDFLAGS="$(TARGET_LDFLAGS)"

GO_PKG_BUILD_VARS= \
	GOPATH=$(GO_PKG_BUILD_DIR) \
	GOCACHE=$(GO_PKG_CACHE_DIR) \
	GOENV=off

GO_PKG_DEFAULT_VARS= \
	$(GO_PKG_TARGET_VARS) \
	$(GO_PKG_BUILD_VARS)

GO_PKG_VARS=$(GO_PKG_DEFAULT_VARS)

# do not use for new code; this will be removed after the next OpenWrt release
GoPackage/Environment=$(GO_PKG_VARS)

GO_PKG_DEFAULT_LDFLAGS= \
	-buildid '$(SOURCE_DATE_EPOCH)' \
	-linkmode external \
	-extldflags '$(patsubst -z%,-Wl$(comma)-z$(comma)%,$(TARGET_LDFLAGS))'

GO_PKG_INSTALL_ARGS= \
	-v \
	-trimpath \
	-ldflags "all=$(GO_PKG_DEFAULT_LDFLAGS)"

ifeq ($(GO_PKG_ENABLE_PIE),1)
  GO_PKG_INSTALL_ARGS+= -buildmode pie
endif

ifeq ($(GO_ARCH),arm)
  GO_PKG_INSTALL_ARGS+= -installsuffix "v$(GO_ARM)"

else ifneq ($(filter $(GO_ARCH),mips mipsle),)
  GO_PKG_INSTALL_ARGS+= -installsuffix "$(GO_MIPS)"

else ifneq ($(filter $(GO_ARCH),mips64 mips64le),)
  GO_PKG_INSTALL_ARGS+= -installsuffix "$(GO_MIPS64)"

endif

ifneq ($(strip $(GO_PKG_GCFLAGS)),)
  GO_PKG_INSTALL_ARGS+= -gcflags "$(GO_PKG_GCFLAGS)"
endif

GO_PKG_CUSTOM_LDFLAGS= \
	$(GO_PKG_LDFLAGS) \
	$(patsubst %,-X %,$(GO_PKG_LDFLAGS_X))

ifneq ($(strip $(GO_PKG_CUSTOM_LDFLAGS)),)
  GO_PKG_INSTALL_ARGS+= -ldflags "$(GO_PKG_CUSTOM_LDFLAGS) $(GO_PKG_DEFAULT_LDFLAGS)"
endif

# false if directory does not exist
GoPackage/is_dir_not_empty=$$$$($(FIND) $(1) -maxdepth 0 -type d \! -empty 2>/dev/null)

GoPackage/has_binaries=$(call GoPackage/is_dir_not_empty,$(GO_PKG_BUILD_BIN_DIR))

define GoPackage/Build/Configure
	( \
		cd $(PKG_BUILD_DIR) ; \
		mkdir -p $(GO_PKG_BUILD_DIR)/bin $(GO_PKG_BUILD_DIR)/src $(GO_PKG_CACHE_DIR) ; \
		\
		files=$$$$($(FIND) ./ \
			-type d -a \( -path './.git' -o -path './$(GO_PKG_WORK_DIR_NAME)' \) -prune -o \
			\! -type d -print | \
			sed 's|^\./||') ; \
		\
		if [ "$(strip $(GO_PKG_INSTALL_ALL))" != 1 ]; then \
			code=$$$$(echo "$$$$files" | grep '\.\(c\|cc\|cpp\|go\|h\|hh\|hpp\|proto\|s\)$$$$') ; \
			testdata=$$$$(echo "$$$$files" | grep '\(^\|/\)testdata/') ; \
			gomod=$$$$(echo "$$$$files" | grep '\(^\|/\)go\.\(mod\|sum\)$$$$') ; \
			\
			for pattern in $(GO_PKG_INSTALL_EXTRA); do \
				extra=$$$$(echo "$$$$extra"; echo "$$$$files" | grep "$$$$pattern") ; \
			done ; \
			\
			files=$$$$(echo "$$$$code"; echo "$$$$testdata"; echo "$$$$gomod"; echo "$$$$extra") ; \
			files=$$$$(echo "$$$$files" | grep -v '^[[:space:]]*$$$$' | sort -u) ; \
		fi ; \
		\
		IFS=$$$$'\n' ; \
		\
		echo "Copying files from $(PKG_BUILD_DIR) into $(GO_PKG_BUILD_DIR)/src/$(strip $(GO_PKG))" ; \
		for file in $$$$files; do \
			echo $$$$file ; \
			dest=$(GO_PKG_BUILD_DIR)/src/$(strip $(GO_PKG))/$$$$file ; \
			mkdir -p $$$$(dirname $$$$dest) ; \
			$(CP) $$$$file $$$$dest ; \
		done ; \
		echo ; \
		\
		link_contents() { \
			local src=$$$$1 ; \
			local dest=$$$$2 ; \
			local dirs dir base ; \
			\
			if [ -n "$$$$($(FIND) $$$$src -mindepth 1 -maxdepth 1 -name '*.go' \! -type d)" ]; then \
				echo "$$$$src is already a Go library" ; \
				return 1 ; \
			fi ; \
			\
			dirs=$$$$($(FIND) $$$$src -mindepth 1 -maxdepth 1 -type d) ; \
			for dir in $$$$dirs; do \
				base=$$$$(basename $$$$dir) ; \
				if [ -d $$$$dest/$$$$base ]; then \
					case $$$$dir in \
					*$(GO_PKG_PATH)/src/$(strip $(GO_PKG))) \
						echo "$(strip $(GO_PKG)) is already installed. Please check for circular dependencies." ;; \
					*) \
						link_contents $$$$src/$$$$base $$$$dest/$$$$base ;; \
					esac ; \
				else \
					echo "...$$$${src#$(GO_PKG_BUILD_DEPENDS_SRC)}/$$$$base" ; \
					$(LN) $$$$src/$$$$base $$$$dest/$$$$base ; \
				fi ; \
			done ; \
		} ; \
		\
		if [ "$(strip $(GO_PKG_SOURCE_ONLY))" != 1 ]; then \
			if [ -d $(GO_PKG_BUILD_DEPENDS_SRC) ]; then \
				echo "Symlinking directories from $(GO_PKG_BUILD_DEPENDS_SRC) into $(GO_PKG_BUILD_DIR)/src" ; \
				link_contents $(GO_PKG_BUILD_DEPENDS_SRC) $(GO_PKG_BUILD_DIR)/src ; \
			else \
				echo "$(GO_PKG_BUILD_DEPENDS_SRC) does not exist, skipping symlinks" ; \
			fi ; \
		else \
			echo "Not building binaries, skipping symlinks" ; \
		fi ; \
		echo ; \
	)
endef

# $(1) additional arguments for go command line (optional)
define GoPackage/Build/Compile
	( \
		cd $(GO_PKG_BUILD_DIR) ; \
		export $(GO_PKG_VARS) ; \
		\
		echo "Finding targets" ; \
		targets=$$$$(go list $(GO_PKG_BUILD_PKG)) ; \
		for pattern in $(GO_PKG_EXCLUDES); do \
			targets=$$$$(echo "$$$$targets" | grep -v "$$$$pattern") ; \
		done ; \
		echo ; \
		\
		if [ "$(strip $(GO_PKG_GO_GENERATE))" = 1 ]; then \
			echo "Calling go generate" ; \
			go generate -v $(1) $$$$targets ; \
			echo ; \
		fi ; \
		\
		if [ "$(strip $(GO_PKG_SOURCE_ONLY))" != 1 ]; then \
			echo "Building targets" ; \
			go install $(GO_PKG_INSTALL_ARGS) $(1) $$$$targets ; \
			retval=$$$$? ; \
			echo ; \
			\
			if [ "$$$$retval" -eq 0 ] && [ -z "$(call GoPackage/has_binaries)" ]; then \
				echo "No binaries were generated, consider adding GO_PKG_SOURCE_ONLY:=1 to Makefile" ; \
				echo ; \
			fi ; \
			\
			echo "Cleaning module download cache (golang/go#27455)" ; \
			go clean -modcache ; \
			echo ; \
		fi ; \
		exit $$$$retval ; \
	)
endef

define GoPackage/Build/InstallDev
	$(call GoPackage/Package/Install/Src,$(1))
endef

define GoPackage/Package/Install/Bin
	if [ -n "$(call GoPackage/has_binaries)" ]; then \
		$(INSTALL_DIR) $(1)/opt/bin ; \
		$(INSTALL_BIN) $(GO_PKG_BUILD_BIN_DIR)/* $(1)/opt/bin/ ; \
	fi
endef

define GoPackage/Package/Install/Src
	dir=$$$$(dirname $(GO_PKG)) ; \
	$(INSTALL_DIR) $(1)$(GO_PKG_PATH)/src/$$$$dir ; \
	$(CP) $(GO_PKG_BUILD_DIR)/src/$(strip $(GO_PKG)) $(1)$(GO_PKG_PATH)/src/$$$$dir/
endef

define GoPackage/Package/Install
	$(call GoPackage/Package/Install/Bin,$(1))
	$(call GoPackage/Package/Install/Src,$(1))
endef


ifneq ($(strip $(GO_PKG)),)
  Build/Configure=$(call GoPackage/Build/Configure)
  Build/Compile=$(call GoPackage/Build/Compile)
  Build/InstallDev=$(call GoPackage/Build/InstallDev,$(1))
endif

define GoPackage
  ifndef Package/$(1)/install
    Package/$(1)/install=$$(call GoPackage/Package/Install,$$(1))
  endif
endef

define GoBinPackage
  ifndef Package/$(1)/install
    Package/$(1)/install=$$(call GoPackage/Package/Install/Bin,$$(1))
  endif
endef

define GoSrcPackage
  ifndef Package/$(1)/install
    Package/$(1)/install=$$(call GoPackage/Package/Install/Src,$$(1))
  endif
endef
