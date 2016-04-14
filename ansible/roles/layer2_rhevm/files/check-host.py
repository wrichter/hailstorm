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
SEARCH =        sys.argv[1]

#lets just check that the certificates are in place
while not os.path.isfile(CA):
    print "Missing certificate, attempting to get from the server"
    CERT = urllib2.urlopen("https://rhevm.example.com/ca.crt")
    output = open(CA,'wb')
    output.write(CERT.read())
    output.close()

try:

    api = API(url=URL, username=USERNAME, password=PASSWORD, ca_file=CA)
    h_list = api.hosts.list()

    for h in h_list:
        #print h.get_name()
        if SEARCH == h.get_name():
          print "found"
          sys.exit(0)

    #print "notfound"
    sys.exit(0)

except Exception as ex:
    print "Unexpected error: %s" % ex

