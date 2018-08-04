#
# Yuan Jianpeng <yuanjp@hust.edu.cn>
# 2018/3/26
#

TOP_DIR := $(PWD)
PHONY :=

PHONY += all all_prep uboot
all: all_prep toolchain 
	@$(BUILDTIME) all 1

all_prep:
	@$(BUILDTIME) all 0

include common.mk
include $(TOOLCHAIN_DIR)/Makefile
include $(USERSPACE_DIR)/Makefile

PHONY += toolchain
toolchain: install_toolchain ;

################### U-Boot #####################

PHONY += uboot_prep uboot_defconfig uboot_menuconfig uboot_bakconfig \
		uboot_modelconfig uboot_spl uboot uboot_merge_spl \
		uboot_cscope uboot_clean

UBOOT_ENV := cd $(UBOOT_DIR) && ARCH=arm64 CROSS_COMPILE=$(TOOLCHAIN_BIN_PREFIX) \
			make O=$(UBOOT_BUILD_DIR)/

uboot_prep:
	[ -d $(UBOOT_BUILD_DIR) ] || mkdir -p $(UBOOT_BUILD_DIR)

uboot_defconfig: uboot_prep
	$(UBOOT_ENV) rpi_3_defconfig

uboot_menuconfig: uboot_prep
	$(UBOOT_ENV) menuconfig

uboot_bakconfig: 
	cp $(UBOOT_BUILD_DIR)/.config $(TARGET_DIR)/uboot.config

uboot_modelconfig: uboot_prep
	cp $(TARGET_DIR)/uboot.config $(UBOOT_BUILD_DIR)/.config 

uboot_spl: uboot_modelconfig 
	$(UBOOT_ENV) -j$(JOBS) spl/u-boot-spl.bin

uboot: uboot_modelconfig
	@$(BUILDTIME) $@ 0
	$(UBOOT_ENV) -j$(JOBS)
	@$(BUILDTIME) $@ 1

uboot_cscope:
	cd $(UBOOT_DIR) ; \
	find -L ./arch/arm/ ./board/jz2440 ./cmd ./common \
		./disk ./drivers ./env ./fs ./lib ./net ./include -name '*.[chS]' -print > \
		cscope.files; \
	cscope -b -q -k

uboot_clean:
	rm -fr $(UBOOT_BUILD_DIR)

#################### Kernel ########################

PHONY += kernel_prep kernel_defconfig kernel_menuconfig kernel_bakconfig \
		kernel_modelconfig kernel kernel_cscope kernel_clean

KERNEL_ENV := cd $(KERNEL_DIR) && ARCH=$(ARCH) CROSS_COMPILE=$(TOOLCHAIN_BIN_PREFIX) \
				make O=$(KERNEL_BUILD_DIR)/

kernel_prep:
	[ -d $(KERNEL_BUILD_DIR) ] || mkdir -p $(KERNEL_BUILD_DIR)

kernel_defconfig: kernel_prep
	$(KERNEL_ENV) bcmrpi3_defconfig

kernel_menuconfig: kernel_prep
	$(KERNEL_ENV) menuconfig
	cp $(KERNEL_BUILD_DIR)/.config $(TARGET_DIR)/kernel.config

kernel_bakconfig:
	cp $(KERNEL_BUILD_DIR)/.config $(TARGET_DIR)/kernel.config

kernel_modelconfig: kernel_prep
	cp $(TARGET_DIR)/kernel.config $(KERNEL_BUILD_DIR)/.config

kernel: kernel_modelconfig
	@$(BUILDTIME) $@ 0
	$(KERNEL_ENV) -j$(JOBS)
	@$(BUILDTIME) $@ 1

kernel_image:
	$(KERNEL_ENV) Image

kernel_modules_install:
	rm -fr $(FS_MODULES_DIR)
	$(KERNEL_ENV) INSTALL_MOD_STRIP=1 INSTALL_MOD_PATH=$(FS_MODULES_DIR) modules_install

kernel_dtb:
	$(KERNEL_ENV) broadcom/bcm2837-rpi-3-b.dtb

kernel_dtb_install:
	$(KERNEL_ENV) INSTALL_DTBS_PATH=/work/dtbs dtbs_install

kernel_cscope:
	$(KERNEL_ENV) cscope

kernel_clean:
	rm -fr $(KERNEL_BUILD_DIR)

############### Out of tree Modules #############


################# Userspace ###############
PHONY += userspace_prep userspace userspace_clean

userspace_prep:
	@$(BUILDTIME) userspace 0
	[ -d $(USERSPACE_BUILD_DIR) ] || mkdir -p $(USERSPACE_BUILD_DIR)

userspace: userspace_prep $(PROGRAMS)
	@$(BUILDTIME) $@ 1

userspace_clean: userspace_build_clean userspace_dev_clean userspace_install_clean;

userspace_build_clean:
	rm -fr $(USERSPACE_BUILD_DIR)

userspace_dev_clean:
	rm -fr $(FS_DEV_DIR)

userspace_install_clean:
	rm -fr $(FS_INSTALL_DIR)

userspace_install: $(PROGRAMS_INSTALL);

################ Rootfs ##################
PHONY += rootfs

glibc_libs := ld-* libc-* libc.* libm-* libm.* libdl-* libdl.* \
				libpthread-* libpthread.*
fs_libc_install:
	rm -fr $(FS_LIBC_DIR)
	$(INSTALL) -d $(FS_LIBC_DIR)/lib
	$(INSTALL) -d $(FS_LIBC_DIR)/usr/bin
	for lib in $(glibc_libs) ; do \
		cp -a $(TOOLCHIAN_SYSROOT_DIR)/lib/$${lib} $(FS_LIBC_DIR)/lib/ ; \
	done
	ln -s lib $(FS_LIBC_DIR)/lib64
	cp -a $(TOOLCHIAN_SYSROOT_DIR)/usr/bin/ldd $(FS_LIBC_DIR)/usr/bin/

rootfs:
	@$(BUILDTIME) rootfs 0
	$(INSTALL) -d $(FS_ROOT_DIR)/dev
	$(INSTALL) -d $(FS_ROOT_DIR)/run
	$(INSTALL) -d $(FS_ROOT_DIR)/dev/pts
	$(INSTALL) -d $(FS_ROOT_DIR)/proc
	$(INSTALL) -d $(FS_ROOT_DIR)/sys
	$(INSTALL) -d $(FS_ROOT_DIR)/tmp
	@$(INSTALL_DIR) $(FS_LIBC_DIR)/ $(FS_ROOT_DIR)/
	@$(INSTALL_DIR) $(FS_COMMON_DIR)/ $(FS_ROOT_DIR)/
	@$(INSTALL_DIR) $(FS_INSTALL_DIR)/ $(FS_ROOT_DIR)/ sub
	@$(INSTALL_DIR) $(FS_MODULES_DIR)/ $(FS_ROOT_DIR)/
	@$(BUILDTIME) rootfs 1

rootfs_clean:
	rm -fr $(FS_ROOT_DIR)

################ tftpboot ##################

PHONY += tftpboot_prep tftpboot

tftpboot_prep:
	[ -d $(TFTP_BOOT_DIR) ] || mkdir -p $(TFTP_BOOT_DIR)

$(TFTP_BOOT_DIR)/kernel8.img: $(KERNEL_BUILD_DIR)/arch/arm64/boot/Image
	cp $< $@ 

$(TFTP_BOOT_DIR)/rpi-3-b.dtb: $(TARGET_DIR)/rpi-3-b.dts
	$(KERNEL_BUILD_DIR)/scripts/dtc/dtc -I dts -O dtb $< > $@

tftpboot: tftpboot_prep $(TFTP_BOOT_DIR)/kernel8.img $(TFTP_BOOT_DIR)/rpi-3-b.dtb
	@$(INSTALL_DIR) $(TARGET_DIR)/tftpboot/ $(TFTP_BOOT_DIR)/
	 
tftpboot_clean:
	rm -fr $(TFTP_BOOT_DIR)

.PHONY: $(PHONY)
