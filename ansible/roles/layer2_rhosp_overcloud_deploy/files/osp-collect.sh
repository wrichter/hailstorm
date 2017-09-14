#!/bin/bash

{
# name[0]:VMs[1]:CPUs[2]:MEM[3]:HDD[4]:NICs[5]
#source /home/stack/bin/osp-env.sh || exit 1
source stackrc || exit 1

osp-status.sh
openstack overcloud profiles list

echo -e "\nOSP deployment\n======================================================="
cat deploy_overcloud.log

echo -e "\n\n"
openstack stack failures list --long overcloud
{ openstack stack resource list -n5 overcloud | grep -v _COMPLETE | awk '/OS::/ {print $12,$2,$4}' | while read line; do
  stack="`echo $line|cut -d\  -f1`"
  resource="`echo $line|cut -d\  -f2`"
  physid="`echo $line|cut -d\  -f3`"
  openstack stack resource show "$stack" "$resource"
  echo
  openstack software deployment output show $physid --all --long
  echo
done }
echo

for node in `nova list|awk '/Running/ {print $2}'`; do
  echo -e "\n##############################################################################################"
  echo "# Collecting data for node `nova show $node|grep " name "|awk '{print $4}'` at `date`..."
  echo -e "##############################################################################################\n"
  PSSH="-oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -q"
  ssh $PSSH heat-admin@`echo \`nova show $node|grep ctlplane|cut -d\| -f3\`` 2>&1 <<EOF
echo -e "\`date\` \`hostname\`\n======================================================="
free -h;echo;df -h;echo;timedatectl;echo;lsblk;echo;ip -d a;echo;route -n;echo;[ -e /bin/ovs-vsctl ] && sudo ovs-vsctl show;echo;cat /etc/os-net-config/config.json | python -m json.tool;echo;ls -l /dev/disk/by-{uuid,label,part*}
if [[ \`hostname\` = *"control"* ]]; then
  echo -e "\nPacemaker\n======================================================="
  sudo pcs status &
  PID=\$!
  sleep 5s
  sudo kill \$PID 2>/dev/null
  echo -e "\nCeph\n======================================================="
  sudo ceph status &
  PID=\$!
  sleep 5s
  sudo kill \$PID
  echo -e "\n"
  sudo ceph osd tree &
  PID=\$!
  sleep 5s
  sudo kill \$PID 2>/dev/null
elif [[ \`hostname\` = *"ceph"* ]]; then
  echo -e "\nCeph\n======================================================="
  sudo ceph status &
  PID=\$!
  sleep 5s
  sudo kill \$PID
fi
echo -e "\nFirstboot\n======================================================="
sudo cat /var/log/cloud-init.log
echo -e "\nOOM\n======================================================="
sudo grep -i OOM /var/log/messages
sudo grep -i fork /var/log/messages
echo -e "\nJOURNAL os-collect-config\n======================================================="
sudo journalctl -u os-collect-config | grep -i ERROR
echo -e "\nsyslog's last 200 lines\n======================================================="
sudo tail -200 /var/log/messages
EOF
done
} | less