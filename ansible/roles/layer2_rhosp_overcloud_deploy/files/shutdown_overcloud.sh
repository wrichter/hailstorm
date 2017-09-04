#!/bin/bash

help() {
  cat <<EOF
Usage: $0 [-h]

This script shuts down the overcloud.
EOF
  exit 0
}

[ "$1" = "-h" ] && help

# name[0]:VMs[1]:CPUs[2]:MEM[3]:HDD[4]:NICs[5]
source /home/stack/bin/osp-env.sh || exit 1

# stop instances
read -p "press return for stopping instances..."
source ~/overcloudrc || exit 1
for vm in `nova list --all-tenants 2>/dev/null|awk '{print $2}'|grep -v "ID\|^$"`; do
  nova stop $vm 2>/dev/null
done
nova list --all-tenants 2>/dev/null

# poweroff computes
read -p "press return for powering off compute nodes..."
cat <<EOF
Hint: It's normal to see here
      'Failed to connect to the host via ssh: Shared connection to <IP> closed.'
      as the poweroff closes the connection to ansible.

EOF
ansible computes -b -m shell -a "poweroff"
sleep 30s
nova service-list 2>/dev/null

# disable pacemaker
read -p "press return for disabling pacemaker..."
source stackrc || exit 1
#CONTROLLER=$(nova list 2>/dev/null| grep overcloud-controller | awk '{print $12}' | head -1 | cut -f2 -d=)
CONTROLLER="4.239.239.161"
ansible $CONTROLLER -b -m shell -a "pcs cluster stop --all"
sleep 30s
ansible $CONTROLLER -b -m shell -a "pcs status"

# poweroff controllers
read -p "press return for powering off controller nodes..."
cat <<EOF
Hint: It's normal to see here
      'Failed to connect to the host via ssh: Shared connection to <IP> closed.'
      as the poweroff closes the connection to ansible.

EOF
ansible controllers -b -m shell -a "poweroff"

# show the status
echo "You will see the status of the overcloud in 3m..."
( sleep 3m; source ~/stackrc; ironic node-list ) &
