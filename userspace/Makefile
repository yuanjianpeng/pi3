#
# Herbert Yuan <yuanjp@hust.eud.cn>
# 2018/2/4
#

# this Makefile is included by the top Makefile.
# so all rules are available at main Makefile.
# don't use this file directly.

PROGRAMS :=
PROGRAMS_INSTALL :=
PROGRAMS_CLEAN :=
USERSPACE_CROSS_BUILD := CROSS_COMPILE=$(TOOLCHAIN_BIN_PREFIX)

################### busybox #########################
PROGRAMS += busybox
PROGRAMS_INSTALL += busybox_install

PHONY += busybox_prep busybox_defconfig busybox_menuconfig \
		busybox_bakconfig busybox_modelconfig busybox_build \
		busybox_install busybox busybox_clean

busybox_package := busybox-1.28.0
busybox_output := $(USERSPACE_BUILD_DIR)/$(busybox_package)
busybox_path := $(USERSPACE_DIR)/gpl/$(busybox_package)
busybox_install_path := $(FS_INSTALL_DIR)/$(busybox_package)
busybox_env := cd $(busybox_path) && $(USERSPACE_CROSS_BUILD) \
			make O=$(busybox_output)/

busybox_prep:
	[ -d $(busybox_output) ] || mkdir -p $(busybox_output)

busybox_defconfig: | busybox_prep
	$(busybox_env) defconfig

busybox_menuconfig: | busybox_prep
	$(busybox_env) menuconfig

busybox_bakconfig:
	cp $(busybox_output)/.config $(TARGET_DIR)/busybox.config

busybox_modelconfig: | busybox_prep
	cp $(TARGET_DIR)/busybox.config $(busybox_output)/.config

busybox: busybox_modelconfig
	$(busybox_env) -j$(JOBS)

busybox_install_clean: 
	rm -fr $(busybox_install_path)

busybox_install: busybox_install_clean
	$(busybox_env) install CONFIG_PREFIX=$(busybox_install_path)

busybox_clean:
	rm -fr $(busybox_output) $(busybox_install_path)

