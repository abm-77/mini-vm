fs:
	mkdir -p sysroot/ rootfs/
	cd ./rootfs; \
		mkdir -p dev bin sbin etc proc sys usr/bin usr/sbin; \
		mknod -m 622 ./dev/console c 5 1; \
		mknod -m 666 ./dev/null c 1 3; \
	cat $(realpath ./scripts)/init > $(shell realpath ./rootfs)/init 
	cat $(realpath ./scripts)/init_dropbear > $(shell realpath ./rootfs)/init_dropbear
	chmod +x $(shell realpath ./rootfs)/init
	chmod +x $(shell realpath ./rootfs)/init_dropbear

musl: fs
	cd ./musl; \
		./configure --target=x86_64-linux-gnu --prefix=$(shell realpath ./sysroot); \
		$(MAKE) install;

kernel: musl
	$(MAKE) -C ./linux-stable/ defconfig
	$(MAKE) -C ./linux-stable/ -j25
	cd ./linux-stable; \
		$(MAKE) headers_install INSTALL_HDR_PATH=$(shell realpath ./sysroot);

busybox: kernel
	git apply patches/busybox-1.36.1-no-cbq.patch
	cat $(shell realpath ./scripts)/busybox_config > $(shell realpath ./busybox)/.config
	cd ./busybox; \
		$(MAKE) install;

dropbear: busybox
	cd ./dropbear; \
		sed -i 's/ getrandom//' configure.ac; \
		autoconf; \
		./configure \
			--host=x86_64-linux-gnu \
			--prefix=$(shell realpath ./rootfs) \
			--disable-zlib \
			--enable-static \
			CC="x86_64-linux-gnu-gcc -specs $(shell realpath ./sysroot)/lib/musl-gcc.specs" \
			LD=ld; \
		$(MAKE) PROGRAMS="dropbear dropbearkey scp" STATIC=1; \
		$(MAKE) PROGRAMS="dropbear dropbearkey scp" STATIC=1 install;

# must be run with fakeroot!
initramfs: dropbear
	cd ./rootfs; \
		mkdir -p dev bin sbin etc proc sys usr/bin usr/sbin; \
		mknod -m 622 ./dev/console c 5 1; \
		mknod -m 666 ./dev/null c 1 3; \
		find . -print0 | cpio --null -ov --format=newc | gzip -9 >$(shell realpath ./initramfs.cpio.gz);

build_deps: initramfs

vm: 
	qemu-system-x86_64 \
		-nographic \
		-cpu host \
		-enable-kvm \
		-m 2048 \
		-smp 8 \
		-netdev user,id=mynet,hostfwd=tcp::5522-:5522 \
  	-device virtio-net-pci,netdev=mynet \
		-kernel ./linux-stable/arch/x86_64/boot/bzImage \
		-append "console=ttyS0 init=/init serial" \
		-initrd ./initramfs.cpio.gz

clean:
	rm -rf sysroot/ rootfs/ initramfs.cpio.gz
