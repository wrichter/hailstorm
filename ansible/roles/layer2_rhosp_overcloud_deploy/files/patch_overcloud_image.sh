#!/bin/bash

help() {
cat <<EOF
Usage: $0 [-h]

This script patches the overcloud image with the rpms in $ADDRPMS (e.g. multipath)
and all scripts templates/*.cmd. The script provided for installing $ADDRPMS should
be the first one and is thus named templates/01_patch-overcloud.cmd.

EOF
exit 0
}

[ "$1" = "-h" ] && help

source osp-env.sh || exit 1
source stackrc || exit 1

cd
[ -e images/overcloud-full.qcow2 ] || exit 1
echo -n "saving original image as overcloud-full.qcow2.org... "
[ -e images/overcloud-full.qcow2.org ] || cp -a images/overcloud-full.qcow2 images/overcloud-full.qcow2.org

if [ "$ADDRPMS" != "" ]; then
  echo -n "downloading rpms $ADDRPMS... "
  mkdir rpms 2>/dev/null
  cd rpms
  sudo yumdownloader --resolve --downloadonly $ADDRPMS
  cd
fi

if ls -l rpms/* 2>/dev/null; then
  echo -n "copy-in rpms... "
  virt-copy-in -a images/overcloud-full.qcow2 rpms/ /root && echo "done."
  echo
fi

for CMD in templates/*.cmd; do
  echo -n "running $CMD in images/overcloud-full.qcow2... "
  virt-customize -a images/overcloud-full.qcow2 --run $CMD
done

echo -n "uploading images... "
cd ~/images
openstack overcloud image upload --image-path /home/stack/images/ --update-existing
openstack image list
