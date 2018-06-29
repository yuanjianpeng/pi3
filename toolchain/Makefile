TOOLCHAIN_BUILD_DIR := $(OUTPUT_DIR)/toolchain

PHONY += ct_ng_install ct_ng_clean

CT_NG_NAME := $(notdir $(wildcard $(TOOLCHAIN_DIR)/crosstool-ng-*))
tool_ctng_src := $(TOOLCHAIN_DIR)/$(CT_NG_NAME)
tool_ctng_install := $(TOOLCHAIN_BUILD_DIR)/$(CT_NG_NAME)

# crosstool-NG doesn't support out-of-tree build
# so we copy source to build dir, configure as local build
ct_ng_install:
	[ -d $(tool_ctng_install) ] || mkdir -p $(TOOLCHAIN_BUILD_DIR) && \
		cp -r $(tool_ctng_src) $(TOOLCHAIN_BUILD_DIR)
	cd $(tool_ctng_install) && [ -f Makefile ] || ./configure --enable-local
	cd $(tool_ctng_install) && [ -f ct-ng ] || MAKELEVEL=0 make

ct_ng_clean:
	rm -fr $(tool_ctng_install)

CT_NG_TAR_DIR := /work/tar
CT_NG_WORK_DIR := $(TOOLCHAIN_BUILD_DIR)/build
CT_NG_PREFIX_DIR := $(TOOLCHAIN_BUILD_DIR)
CT_NG_KERNEL_SRC := $(KERNEL_DIR)
CT_NG_LINUX_VERSION := $(KERNEL_VERSION)

export CT_NG_TAR_DIR CT_NG_WORK_DIR CT_NG_PREFIX_DIR 
export CT_NG_KERNEL_SRC CT_NG_LINUX_VERSION

PHONY += toolchain_defconfig toolchain_menuconfig toolchain_bakconfig
PHONY += build_toolchain install_toolchain

toolchain_defconfig: ct_ng_install
	cp $(TARGETS_DIR)/ct-ng.config $(tool_ctng_install)/.config

toolchain_menuconfig: ct_ng_install
	cd $(tool_ctng_install) && ./ct-ng menuconfig

toolchain_bakconfig: ct_ng_install
	cp $(tool_ctng_install)/.config $(TARGETS_DIR)/ct-ng.config 

build_toolchain: toolchain_defconfig
	cd $(tool_ctng_install) && JOBS=$(JOBS) ./ct-ng build

tar_toolchain:
	cd $(TOOLCHAIN_BUILD_DIR) && tar cjf $(TOOLCHAIN_TAR_BALL) $(TOOLCHAIN_NAME)

install_toolchain:
	[ -d $(TOOLCHAIN) ] || { mkdir -p $(TOOLCHAIN_INSTALL_DIR) && \
		tar xf $(TOOLCHAIN_TAR_BALL) -C $(TOOLCHAIN_INSTALL_DIR) ; }


