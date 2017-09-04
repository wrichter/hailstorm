#!/bin/bash -x

osp-status.sh
source ~/stackrc || exit 1

if [ "$1" = "--wipe" ] || [ "$2" = "--wipe" ]; then
  for node in `nova list|awk '/Running/ {print $2}'`; do
    echo -e "\n##############################################################################################"
    echo "# Deleting data on node `nova show $node|grep " name "|awk '{print $4}'` at `date`..."
    echo -e "##############################################################################################\n"
    PSSH="-oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -q"
    ssh $PSSH heat-admin@`echo \`nova show $node|grep ctlplane|cut -d\| -f3\`` 2>&1 sudo -i <<"EOF"
      DEV="`lsblk |grep -v "^├\|^└\|^ "|tail -n +2|head -1|awk '{print $1}'`"
      dd if=/dev/zero of=/dev/${DEV}2 bs=1M count=4
      sync
      sgdisk -Z /dev/${DEV}
EOF
  done
fi

if [ "`openstack stack list | tee $0.$$ | grep " overcloud "`" = "" ]; then
  echo "no overcloud to delete..."
else
  openstack stack delete overcloud
  sleep 60s
  while openstack stack list | tee $0.$$ | grep " overcloud "; do
    grep "DELETE_IN_PROGRESS" $0.$$ >/dev/null || openstack stack delete --yes overcloud
    sleep 10s
  done
  rm $0.$$
  openstack stack list
fi

for n in `ironic node-list|grep -v "available\|manageable"|awk '/None/ {print $2}'`; do
  ironic node-set-maintenance $n off
  #ironic node-set-provision-state $n deleted
done

openstack baremetal configure boot

#echo "# set all nodes to a managed/active state"
#for node in $(openstack baremetal node list|awk '{print $2}'|grep -v "UUID\|^$") ; do
  #openstack baremetal node manage $node
#  ironic node-set-provision-state $node active
#done

if [ "$1" = "--all" ] || [ "$2" = "--all" ]; then
  read -p "Attention. You will have to completely re-inventory/introspect your setup. Are you shure [yes|no]? " answer
  if [ "$answer" = "yes" ]; then
    rm ~/instackenv.json
    for n in `ironic node-list|grep -v "available\|manageable"|awk '/None/ {print $2}'`; do
      #ironic node-set-maintenance $n off
      ironic node-set-provision-state $n deleted
    done
    for n in `ironic node-list|awk '/None/ {print $2}'`; do
      ironic node-update $n remove instance_uuid
      ironic node-delete $n
    done
    for n in `nova list|head -n -1|tail -n +4`; do
      nova delete $n
    done
  fi
fi

osp-status.sh
