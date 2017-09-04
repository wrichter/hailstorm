#!/bin/bash

help() {
  cat <<EOF
Usage: $0 [-h]

This script starts the overcloud from the director.

It is closely scripted after https://access.redhat.com/solutions/1977013
EOF
  exit 0
}

[ "$1" = "-h" ] && help

# name[0]:VMs[1]:CPUs[2]:MEM[3]:HDD[4]:NICs[5]
source /home/stack/bin/osp-env.sh || exit 1

# start controllers
read -p "press return for starting the controller nodes..."
source ~/stackrc || exit 1
for bmnode in $(nova list| grep overcloud-controller | awk '{print $2}'); do
  node="`ironic node-list|grep $bmnode|awk '{print $2}'`"
  ironic node-set-power-state $node on
done
sleep 1m
ironic node-list
echo -n "waiting for nodes to come up again"
while ! ansible controllers -b -m ping &>/dev/null; do
  echo -n "."
  sleep 5s
done
echo " done."

# enable pacemaker
read -p "press return for enabling pacemaker..."
#CONTROLLER=$(nova list 2>/dev/null| grep overcloud-controller | awk '{print $12}' | head -1 | cut -f2 -d=)
CONTROLLER="4.239.239.161"
ansible $CONTROLLER -b -m shell -a "pcs cluster start --all"
sleep 30s
ansible $CONTROLLER -b -m shell -a "pcs status"
source ~/overcloudrc || exit 1
nova service-list 2>/dev/null
sleep 2m

# start computes
read -p "press return for starting the compute nodes..."
source ~/stackrc || exit 1
for bmnode in $(nova list| grep overcloud-compute | awk '{print $2}'); do
  node="`ironic node-list|grep $bmnode|awk '{print $2}'`"
  ironic node-set-power-state $node on
done
sleep 1m
ironic node-list
echo -n "waiting for nodes to come up again"
while ! ansible computes -b -m ping &>/dev/null; do
  echo -n "."
  sleep 5s
done
echo " done."
source ~/overcloudrc || exit 1
nova service-list 2>/dev/null

# start VMs
read -p "press return for starting the VMs..."
for vm in `nova list --all-tenants 2>/dev/null|awk '{print $2}'|grep -v "ID\|^$"`; do
  nova start $vm 2>/dev/null
done
sleep 30s
nova list --all-tenants 2>/dev/null

source ~/stackrc || exit 1
ceph-status.sh | head -20
osp-status.sh
