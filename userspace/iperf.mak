PROGRAMS += iperf
PROGRAMS_INSTALL += iperf_install
PROGRAMS_CLEAN += iperf_clean
PHONY += iperf iperf_install iperf_clean

iperf_package := iperf-3.6
iperf_output := $(USERSPACE_BUILD_DIR)/$(iperf_package)
iperf_src := $(USERSPACE_DIR)/gpl/$(iperf_package)
iperf_install_path := $(FS_INSTALL_DIR)/$(iperf_package)

iperf_config_opts := --host=aarch64 \
	--prefix=$(iperf_install_path) \
	--disable-static \
	--with-openssl=$(openssl_dev)

iperf: 
	[ -d $(iperf_output) ] || mkdir -p $(iperf_output)
	cd $(iperf_output) && { [ -f Makefile ] || \
		CC=$(CC) $(iperf_src)/configure $(iperf_config_opts) ; }
	cd $(iperf_output) && make -j$(JOBS) 

iperf_install: 
	rm -fr $(iperf_install_path)
	mkdir -p $(iperf_install_path)/bin
	cp -a $(iperf_output)/src/iperf3 $(iperf_install_path)/bin

iperf_clean:
	rm -fr $(iperf_output) $(iperf_install_path)