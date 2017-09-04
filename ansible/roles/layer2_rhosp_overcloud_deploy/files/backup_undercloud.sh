#!/bin/bash
WHEN="`date +%Y%m%d-%H%m`"
sudo -i <<EOF
mysqldump --opt --all-databases > /root/undercloud-all-databases-${WHEN}.sql
tar -czf undercloud-backup-${WHEN}.tar.gz /root/undercloud-all-databases-${WHEN}.sql /etc/my.cnf.d/server.cnf /var/lib/glance/images /srv/node /home/stack /etc/keystone/ssl /opt/stack

EOF