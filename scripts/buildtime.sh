#!/bin/sh

DIR=$1
TARGET=$2
FILE=${DIR}/.${TARGET}_build_start

[ $3 -eq 0 ] && {
    ST=`cat /proc/uptime | cut -d ' ' -f 1`
    echo $ST > ${FILE}
    return 0
}

ST=`cat ${FILE}`
rm ${FILE}
EN=`cat /proc/uptime | cut -d ' ' -f 1`
T=`echo $EN-$ST | bc`;
echo build ${TARGET} using $T seconds
return 0
