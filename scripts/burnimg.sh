#!/bin/bash

# forbid burn to device whose capacity is larger than this variable
# to protect from a wrong device, unit GiB
MAX_CAP=32	

DEV_NAME=
IMG=
DEV=

usage ()
{
	echo usage: "burnimg.sh -d dev image"
} 1>&2

if [ `whoami` != "root" ] ; then
	echo this script need run as root 1>&2
	exit 1
fi

while [ $# -gt 0 ] ; do
	case $1 in
		-d)
			shift
			[ $# -gt 0 ] || { usage; exit 1; } 
			DEV_NAME=$1
		;;
		-h | --help)
			usage
			exit 0
		;;
		*)
			IMG=$1
	esac
	[ $# -eq 0 ] || shift
done


DEV=/dev/$DEV_NAME

[ -b "$DEV" ] || {
	echo "$DEV is not a block device" 1>&2
	exit 1
}

[ -f "$IMG" ] || {
	echo "image $IMG not found" 1>&2
	exit 1
}

size=`cat /sys/block/$DEV_NAME/size`
[ $? -eq 0 ] || {
	echo "can't get size of $DEV" 1>&2
	exit 1
}

[ "${#size}" -gt 3 ] || {
	echo "error size $size of $DEV" 1>&2
	echo "the device may has been unplugned" 1>&2
	exit 1
}

echo $DEV sectors $size

# to prevent integer overflow
#
size_tail=${size: -3}
size=${size:0:-3}
size=$((size/2+size_tail/2000))

echo $DEV size $((size/1000))GB

max_size=$((MAX_CAP*1000))

[ $size -lt $max_size ] || {
	echo $DEV size is larger than ${MAX_CAP}GB 1>&2
	echo do you input a correct device ? 1>&2
	exit 1
}

parts=`ls $DEV*`

for part in $parts ; do
	[ "$part" != "$DEV" ] || {
		continue
	} 
	if findmnt $part > /dev/null ; then 
		echo umount $part
		umount $part
	fi
	if findmnt $part > /dev/null ; then
		echo "can't umount $part" 1>&2
		exit 1
	fi
done

dd bs=1M if=$IMG of=$DEV status=progress oflag=sync
[ $? -eq 0 ] || {
	echo burn failed 1>&2
	exit 1
}