#!/bin/bash
watch -n60 "tail deploy_overcloud.log;echo -e '\n';free -h;echo -e '\n';openstack stack resource list -n5 overcloud | grep -v _COMPLETE"
