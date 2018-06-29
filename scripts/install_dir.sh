#!/bin/bash -e

# Herbert Yuan <yuanjp@hust.edu.cn>
# this script install a dir to rootfs
#

skip_if_same=1
compare_using_timestamp=1

usage()
{
	echo usage: $0 SRC_DIR DST_DIR [1]
} >&2

do_install ()
{
	while read file ; do
		dst=$1$file
		if [[ ! -L $file && -d $file ]] ; then
			mkdir -p $dst
		else
			if [ $skip_if_same -eq 1 ] ; then
				if [ -e $dst ] ; then
					same=1
					if [ $compare_using_timestamp -eq 1 ] ; then
						if [ $file -nt $dst ] ; then
							same=0
							echo $file is newer
						fi
					else
						cmp $file $dst 1>/dev/null 2>&1 || {
							same=0
							echo $file is modified
							true
						}
					fi
					if [ $same -eq 1 ] ; then
						skip=1
						continue
					fi
				fi
			fi
			rm -f $dst
			cp -a $file $dst
		fi
	done
}

install_dir()
{
	find . -not -path . | do_install $1
}

[ $# -ge 2 ] || {
	echo at least 2 parameters required >&2
	usage
	exit 1
}

SRC=$1
DST=$2
SRCS=.

[ -d "$SRC" ] || {
	echo SRC DIR $SRC not exists >&2
	exit 1
}

mkdir -p "${DST}"

[ -d "$DST" ] || {
	echo mkdir DST DIR $DST failed >&2
	exit 1
}

[ $# -gt 2 ] && {
	echo "install [S] subdir of $SRC"
	cd $SRC
	SRCS=`find -maxdepth 1 -not -path . -type d`
}

for DIR in $SRCS ; do
	if [ $# -gt 2 ] ; then
		echo "install [D] $DIR"
	else
		echo "install [D] $SRC"
	fi
	cd $SRC/$DIR
	install_dir $DST
done

