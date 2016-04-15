#!/usr/bin/python
#
# TODO - checks to see if it already exists
#

import sys
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

api = API(url=URL, username=USERNAME, password=PASSWORD, ca_file=CA)

try:

    dc = api.datacenters.get(name="Default")
    h = api.hosts.get(name=HOST_NAME)

    s = params.Storage(address="192.168.103.1", path="/srv/rhev-sd1", type_="nfs")
    sd_params = params.StorageDomain(name=STORAGE_NAME, data_center=dc, host=h, type_="data", storage_format="v3", storage=s)

    try:
        sd = api.storagedomains.add(sd_params)
        print "Storage Domain '%s' added " % (sd.get_name())
    except Exception as ex:
        print "Adding data storage domain to data center failed: %s." % ex
        sys.exit(1)

    sd_data = api.storagedomains.get(name=STORAGE_NAME)

    try:
        dc_sd = dc.storagedomains.add(sd_data)
        print "Attached data storage domain '%s' to data center '%s' (Status: %s)." % (dc_sd.get_name(), dc.get_name, dc_sd.get_status().get_state())
        #print "attached"
    except Exception as ex:
        print "Attaching data storage domain to data center failed: %s." % ex
        sys.exit(2)


#    api.disconnect()

except Exception as ex:
    print "Unexpected error: %s" % ex

