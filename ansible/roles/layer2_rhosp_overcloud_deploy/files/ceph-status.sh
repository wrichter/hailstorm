#!/bin/bash
help() {
cat <<EOF
Usage: $0 [-h|--pools]

This script checks the ceph installation with some status and can list the pools as well.

EOF
exit 0
}

[ "$1" = "-h" ] && help

#source osp-env.sh || exit 1
source stackrc || exit 1

for COMMAND in "ceph status" "ceph df" "ceph osd tree" "ceph osd pool stats"; do
  echo "# $COMMAND"
  ansible mons -b -m shell -a "$COMMAND"
done

[ "$1" = "--pools" ] || exit
for POOL in images volumes vms; do
  echo "# Content of pool \"$POOL\""
  ansible mons -b -m shell -a "rbd -p $POOL ls -l"
done
