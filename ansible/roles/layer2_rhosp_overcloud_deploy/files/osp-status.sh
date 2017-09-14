#!/bin/bash
source ~/stackrc || exit 1
[ "$1" = "--all" ] && openstack service list
nova list
ironic node-list
openstack baremetal introspection bulk status
openstack stack list
openstack overcloud profiles list
