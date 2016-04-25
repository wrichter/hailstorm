#!/usr/bin/python
#
#

import sys
import time
import os
import socket
import urllib2
from ovirtsdk.api import API
from ovirtsdk.xml import params

VERSION = params.Version(major='3', minor='0')

URL =           'https://rhevm.example.com:443/api'
USERNAME =      'admin@internal'
PASSWORD =      'redhat01'

DC_NAME =       'default'
CLUSTER_NAME =  'default'
HOST_NAME =     'rhevh1.example.com'
STORAGE_NAME =  'SD2-NFS'
EXPORT_NAME =   'SD2-EXPORT'
CA =            './rhevm-ca.crt'

#lets just check that the certificates are in place
while not os.path.isfile(CA):
    print "Missing certificate, attempting to get from the server"
    CERT = urllib2.urlopen("https://rhevm.example.com/ca.crt")
    output = open(CA,'wb')
    output.write(CERT.read())
    output.close()


api = API(url=URL, username=USERNAME, password=PASSWORD, ca_file=CA)

try:

    dc = api.datacenters.get(name="Default")
    h = api.hosts.get(name=HOST_NAME)

    s = params.Storage(address="192.168.103.1", path="/srv/rhev-sd1", type_="nfs")
    sd_params = params.StorageDomain(name=STORAGE_NAME, data_center=dc, host=h, type_="data", storage_format="v3", storage=s)

    try:
        for sd in api.storagedomains.list():
            print sd.name
    except Exception as ex:
        print "Problem listing storage domains %s." % ex
        sys.exit(2)


#    api.disconnect()

except Exception as ex:
    print "Unexpected error: %s" % ex

