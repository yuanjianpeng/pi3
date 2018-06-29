#!/bin/bash

#
# Yuan Jianpeng <yuanjp@hust.eud.cn>
# 2018/3/23
#
# make image for Raspberry Pi sd card boot media
# 
# some code are taken from officail tool
#	https://github.com/RPi-Distro/pi-gen
#
# I also tried to use fuse to make image, 
# the advantage using fuse is that we can build image as unpriviledged user
# 	fuseext2 -o rw+ -o umask=022 -o direct_io ${root_img} ${root_mnt} 
#		cp fs ...
#	fusermount -u $root_mnt
# But Failed, the final image can't boot pi3
#

sector_size=512		# Bytes
part_start=4		# MiB, boot partition start poisition
part_margin=4		# MiB, 
boot_part_min=42	# MiB, FAT32 has min size requirement 
root_part_min=16	# MiB
part_reserved=4		# MiB, final part size is evaluated size plus reserved

bootfs=targets/bootfs
rootfs=targets/rootfs
output=output
image=pi3.img.loose

usage ()
{
	echo usage: "mkimg.sh {options} image"
	echo -e "\t-b bootfs"
	echo -e "\t-r rootfs"
	echo -e "\t-o output dir"
} 1>&2


if [ `whoami` != "root" ] ; then
	echo this script need run as root 1>&2
	exit 1
fi

while [ $# -gt 0 ] ; do
	case $1 in
		-b)
			shift
			[ $# -gt 0 ] || { usage; exit 1; } 
			bootfs=$1
		;;
		-r)
			shift
			[ $# -gt 0 ] || { usage; exit 1; } 
			rootfs=$1
		;;
		-o)
			shift
			[ $# -gt 0 ] || { usage; exit 1; }  
			output=$1
		;;
		-h | --help)
			usage
			exit 0
		;;
		*)
			image=$1
	esac
	[ $# -eq 0 ] || shift
done

if [ ! -d "$output" ] ; then
	echo "output dir $output not found, require an exist output dir" 1>&2
	usage
	exit 1
fi

if [ -z "$image" ] ; then
	echo "image required" 1>&2
	usage
	exit 1
fi

if [ ! -d "$bootfs" ] ; then
	echo "bootfs '$bootfs' not found" 1>&2
	usage
	exit 1
fi

if [ ! -d "$rootfs" ] ; then
	echo "rootfs '$rootfs' not found" 1>&2
	usage
	exit 1
fi


MNT_DIR=${output}/mnt
BOOTFS_DIR=${MNT_DIR}/bootfs
ROOTFS_DIR=${MNT_DIR}/rootfs
IMG_FILE=${output}/${image}
BOOT_OFFSET=
BOOT_SIZE=
ROOT_OFFSET=
ROOT_SIZE=

create_image ()
{
	BOOT_SIZE=`du -s --block-size=${sector_size} --apparent-size $bootfs`
	[ $? -eq 0 ] || {
		echo 'get boot size failed' 1>&2
		exit 1
	}
	BOOT_SIZE=`echo $BOOT_SIZE | cut -s -d ' ' -f1`
	BOOT_SIZE=$((BOOT_SIZE*sector_size/1024/1024+part_reserved))

	if [ $BOOT_SIZE -lt $boot_part_min ] ; then
		BOOT_SIZE=$boot_part_min
	fi

	ROOT_SIZE=`du -s --block-size=${sector_size} --apparent-size $rootfs`
	[ $? -eq 0 ] || {
		echo 'get boot size failed' 1>&2
		exit 1
	}
	ROOT_SIZE=`echo $ROOT_SIZE | cut -s -d ' ' -f1`
	ROOT_SIZE=$((ROOT_SIZE*sector_size/1024/1024+part_reserved))

	if [ $ROOT_SIZE -lt $root_part_min ] ; then
		ROOT_SIZE=$root_part_min
	fi

	image_size=$((part_start+BOOT_SIZE+part_margin+ROOT_SIZE))
	BOOT_OFFSET=$((part_start))
	ROOT_OFFSET=$((part_start+BOOT_SIZE+part_margin))

	echo boot: off ${BOOT_OFFSET}MiB, size ${BOOT_SIZE}MiB
	echo root: off ${ROOT_OFFSET}MiB, size ${ROOT_SIZE}MiB
	echo image: size ${image_size}MiB

	rm -f "${IMG_FILE}"
	truncate ${IMG_FILE} -s ${image_size}MiB || {
		echo ***truncate image failed 1>&2
		rm -f "${IMG_FILE}"
		return 1
	}

	sfdisk "${IMG_FILE}" <<EOT
			label: dos
			unit: sectors
			start= ${BOOT_OFFSET}MiB, size= ${BOOT_SIZE}MiB, type=C
			start= ${ROOT_OFFSET}MiB, size= ${ROOT_SIZE}MiB, type=83
EOT

	if [ $? -ne 0 ] ; then
		echo ***sfdisk failed 1>&2
		rm -f "${IMG_FILE}"
		return 1
	fi
}

write_bootfs ()
{
	mkdir -p ${BOOTFS_DIR}
	[ -d ${BOOTFS_DIR} ] || {
		echo ***failed to create ${BOOTFS_DIR} 1>&2
		return 1
	}

	BOOT_DEV=`losetup --show -f -o ${BOOT_OFFSET}MiB --sizelimit ${BOOT_SIZE}MiB "${IMG_FILE}"`
	if [ $? -ne 0 ] ; then
		echo ***losetup bootfs failed 1>&2
		return 1
	fi

	mkdosfs -n boot -F 32 -v "$BOOT_DEV" || {
		echo ***mkdosfs failed 1>&2
		losetup -d ${BOOT_DEV} 
		return 1
	}

	mount -v "$BOOT_DEV" "${BOOTFS_DIR}" -t vfat || {
		echo ***mount bootfs failed 1>&2
		losetup -d ${BOOT_DEV} 
		return 1
	}

	fail=0
	cp -dR ${bootfs}/. ${BOOTFS_DIR} || {
		echo ***cp bootfs failed failed 1>&2
		fail=1
	}

	umount $BOOT_DEV || {
		echo ***umount boot dev failed 1>&2
		fail=1
	}

	losetup -d ${BOOT_DEV} || {
		echo ***losetup detach boot dev failed 1>&2
		fail=1
	}

	return $fail
}

write_rootfs ()
{
	mkdir -p ${ROOTFS_DIR}
	[ -d ${ROOTFS_DIR} ] || {
		echo ***failed to create ${ROOTFS_DIR} 1>&2
		return 1
	}

	ROOT_DEV=`losetup --show -f -o ${ROOT_OFFSET}MiB --sizelimit ${ROOT_SIZE}MiB "${IMG_FILE}"`
	if [ $? -ne 0 ] ; then
		echo ***losetup rootfs failed 1>&2
		return 1
	fi

	ROOT_FEATURES="^huge_file"
	for FEATURE in metadata_csum 64bit; do
		if grep -q "$FEATURE" /etc/mke2fs.conf; then
		    ROOT_FEATURES="^$FEATURE,$ROOT_FEATURES"
		fi
	done

	mkfs.ext4 -L rootfs -O "$ROOT_FEATURES" "$ROOT_DEV" > /dev/null || {
		echo ***mkfs.ext4 failed 1>&2
		losetup -d ${ROOT_DEV} 
		fail=1
	}

	mount -v "$ROOT_DEV" "${ROOTFS_DIR}" -t ext4 || {
		echo ***mount rootfs failed 1>&2
		losetup -d ${ROOT_DEV} 
		return 1
	}

	fail=0
	rsync -aHAXx --exclude var/cache/apt/archives "${rootfs}/" "${ROOTFS_DIR}/" || {
		echo ***rsync bootfs failed 1>&2
		fail=1
	}

	umount $ROOT_DEV || {
		echo ***umount boot dev failed 1>&2
		fail=1
	}

	losetup -d ${ROOT_DEV} || {
		echo ***losetup detach boot dev failed 1>&2
		fail=1
	}

	return $fail
}

create_image || {
	exit 1
}

rm -fr "${MNT_DIR}"

write_bootfs || {
	rm -fr "${MNT_DIR}" "${IMG_FILE}"
	exit 1
}

write_rootfs || {
	rm -fr "${MNT_DIR}" "${IMG_FILE}"
	exit 1
}

rm -fr "${MNT_DIR}"
echo "Raspberry Pi Image create done, path: $IMG_FILE"

