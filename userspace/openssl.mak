PROGRAMS += openssl
PROGRAMS_INSTALL += openssl_install
PROGRAMS_CLEAN += openssl_clean
PHONY += openssl openssl_install openssl_clean

openssl_package := openssl-1.1.1-pre8
openssl_output := $(USERSPACE_BUILD_DIR)/$(openssl_package)
openssl_src := $(USERSPACE_DIR)/gpl/$(openssl_package)
openssl_install := $(FS_INSTALL_DIR)/$(openssl_package)
openssl_dev := $(FS_DEV_DIR)/$(openssl_package)

openssl_config_opt := linux-aarch64 \
	--cross-compile-prefix=$(TOOLCHAIN_BIN_PREFIX) \
	--prefix=$(openssl_install)

openssl_build:
	[ -d $(openssl_output) ] || mkdir -p $(openssl_output)
	cd $(openssl_output) && { [ -f Makefile ] || \
		$(openssl_src)/Configure $(openssl_config_opt) ; }
	cd $(openssl_output) && make -j$(JOBS)

openssl: openssl_build openssl_dev_isntall;

openssl_dev_isntall:
	rm -fr $(openssl_dev)
	cd $(openssl_output) && make INSTALLTOP=$(openssl_dev) install_dev

openssl_install:
	rm -fr $(openssl_install)
	cd $(openssl_output) && make install_runtime

openssl_clean:
	rm -fr $(openssl_output) $(openssl_install) $(openssl_dev)