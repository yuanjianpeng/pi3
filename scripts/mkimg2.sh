#!/bin/bash

#
# Yuan Jianpeng <yuanjp@hust.eud.cn>
# 2018/3/23
#
# make image for Raspberry Pi sd card boot media
# 
# some scripts are taken from officail tool
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

# default value
bootfs=targets/bootfs
rootfs=targets/rootfs
output=output
image=pi3.img.fuse

usage ()
{
	echo usage: "mkimg.sh {options} image"
	echo -e "\t-b bootfs"
	echo -e "\t-r rootfs"
	echo -e "\t-o output dir"
} 1>&2

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

[ -d "$output" ] || {
	echo "output dir nout found" 1>&2
	usage
	exit 1
}

[ -d "$bootfs" ] || {
	echo "bootfs '$bootfs' not found" 1>&2
	usage
	exit 1
}

[ -d "$rootfs" ] || {
	echo "rootfs '$rootfs' not found" 1>&2
	usage
	exit 1
}

IMG_FILE="${output}/${image}"
MNT_DIR="${output}/mnt"
BOOT_IMG_FILE="${output}/boot.img"
ROOT_IMG_FILE="${output}/root.img"
BOOT_MNT="${MNT_DIR}/boot"
ROOT_MNT="${MNT_DIR}/root"
BOOT_OFFSET=
BOOT_SIZE=
ROOT_OFFSET=
ROOT_SIZE=
IMG_SIZE=

create_boot_image ()
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

	rm -f "${BOOT_IMG_FILE}"
	truncate "${BOOT_IMG_FILE}" -s ${BOOT_SIZE}MiB || {
		echo ***truncate boot image failed 1>&2
		rm -f "${BOOT_IMG_FILE}"
		return 1
	}

	mkdosfs -F 32 -v "${BOOT_IMG_FILE}" || {
		echo ***mkdosfs failed 1>&2
		rm -f "${BOOT_IMG_FILE}"
		return 1
	}

	rm -fr "${BOOT_MNT}"
	mkdir -p "${BOOT_MNT}"
	fusefat -o rw+ -o umask=022 -o direct_io \
		-o uid=0 -o gid=0 \
		${BOOT_IMG_FILE} ${BOOT_MNT} || {
		echo ***fusefat boot fs failed 1>&2
		rm -f "${BOOT_IMG_FILE}"
		rm -fr "${BOOT_MNT}"
	}

	fail=0
	cp -dR ${bootfs}/. ${BOOT_MNT} || {
		echo ***cp bootfs failed 1>&2
		fail=1
	}

	fusermount -u $BOOT_MNT || {
		echo ***fusermount -u $BOOT_MNT failed 1>&2
		fail=1
	}

	fatlabel $BOOT_IMG_FILE boot

	[ $fail -eq 0 ] || { rm -fr $BOOT_IMG_FILE ; } 

	rm -fr "${BOOT_MNT}"
	return $fail
}

create_root_image ()
{
	ROOT_SIZE=`du -s --block-size=${sector_size} --apparent-size $rootfs`
	[ $? -eq 0 ] || {
		echo 'get root size failed' 1>&2
		exit 1
	}
	ROOT_SIZE=`echo $ROOT_SIZE | cut -s -d ' ' -f1`
	ROOT_SIZE=$((ROOT_SIZE*sector_size/1024/1024+part_reserved))

	if [ $ROOT_SIZE -lt $root_part_min ] ; then
		ROOT_SIZE=$root_part_min
	fi

	rm -f "${ROOT_IMG_FILE}"
	truncate "${ROOT_IMG_FILE}" -s ${ROOT_SIZE}MiB || {
		echo ***truncate boot image failed 1>&2
		rm -f "${ROOT_IMG_FILE}"
		return 1
	}

	ROOT_FEATURES="^huge_file"
	for FEATURE in metadata_csum 64bit; do
		if grep -q "$FEATURE" /etc/mke2fs.conf; then
		    ROOT_FEATURES="^$FEATURE,$ROOT_FEATURES"
		fi
	done

	mkfs.ext4 -L rootfs -O "$ROOT_FEATURES" "$ROOT_IMG_FILE" > /dev/null || {
		echo ***mkfs.ext4 failed 1>&2 
		rm -f "${ROOT_IMG_FILE}"
		fail=1
	}

	rm -fr "${ROOT_MNT}"
	mkdir -p "${ROOT_MNT}"
	fuseext2 -o rw+ -o umask=022 -o direct_io \
		${ROOT_IMG_FILE} ${ROOT_MNT} || {
		echo ***fusefat root fs failed 1>&2
		rm -f "${ROOT_IMG_FILE}"
		rm -fr "${ROOT_MNT}"
	}

	fail=0
	cp -a ${rootfs}/. ${ROOT_MNT} || {
		echo ***cp bootfs failed 1>&2
		fail=1
	}

	fusermount -u $ROOT_MNT || {
		echo ***fusermount -u $ROOT_MNT failed 1>&2
		fail=1
	}

	[ $fail -eq 0 ] || { rm -fr $ROOT_IMG_FILE ; } 

	rm -fr "${ROOT_MNT}"
	return $fail
}

create_image ()
{
	IMG_SIZE=$((part_start+BOOT_SIZE+part_margin+ROOT_SIZE))
	BOOT_OFFSET=$((part_start))
	ROOT_OFFSET=$((part_start+BOOT_SIZE+part_margin))
	echo image: size ${IMG_SIZE}MiB

	rm -f "${IMG_FILE}"
	truncate ${IMG_FILE} -s ${IMG_SIZE}MiB || {
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

	dd if="${BOOT_IMG_FILE}" of="${IMG_FILE}" bs=1M \
		status=progress oflag=sync seek=${BOOT_OFFSET} || {
		echo ***dd boot image failed 1>&2
		rm -f "${IMG_FILE}"
		return 1
	}

	dd if="${ROOT_IMG_FILE}" of="${IMG_FILE}" bs=1M \
		status=progress oflag=sync seek=${ROOT_OFFSET} || {
		echo ***dd boot image failed 1>&2
		rm -f "${IMG_FILE}"
		return 1
	}
}

create_boot_image || {
	rm -fr "${MNT_DIR}"
	exit 1
}
create_root_image || { 
	rm -fr "${MNT_DIR}"
	exit 1
}
create_image || {
	rm -fr "${MNT_DIR}"
	exit 1
}

rm -fr "${MNT_DIR}"
echo "Raspberry Pi Image create done, path: $IMG_FILE"