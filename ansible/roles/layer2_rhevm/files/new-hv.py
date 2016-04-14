#!/usr/bin/python
#
# Script to add new hypervisors into RHEV-M
#
# Version: 1.2.2
#
# adrian@redhat.com
#
# ToDo: Authentication - LDAP
# ToDo: Much more validation ;-)

import sys
import time
import os
import socket
import urllib2
from ovirtsdk.api import API
from ovirtsdk.xml import params

def usage():
  #The wrong number of parametes was entered or --help requested
  print
  print 'Usage: The HV Add script can run in three modes'
  print
  print 'Mode 1 - DNS Mode'
  print '-----------------'
  print 'First mode requires only one parameter - the short hostname'
  print 'All other information is resolved via DNS lookups'
  print 'If any information cannot be resolved, the process will abort'
  print
  print 'Mode 2 - Parameter Mode'
  print '------------------------'
  print 'In this mode, all information is sent to the script via the use of'
  print 'three parameters:'
  print '          ha-add.py <short name> <ilom address> <move address>'
  print
  print 'For example '
  print '          ha-add.py lxf101s001 10.208.24.42 10.116.100.143'
  print
  print 'Mode 3 - interactive'
  print '---------------------'
  print 'If no paramaters are entered at all, it will fallback into interactive'
  print 'mode, prompting for each piece of information required'
  print
  sys.exit(1)

def summary():
  print
  print 'Summary'
  print '-------'
  print 'Using these settings ...'
  print('Zone: \t\t%s' % ZONE)
  print('Name: \t\t%s' % HOST_NAME)
  print('FQDN: \t\t%s' % HOST_ADDRESS)
  print('Host Address: \t%s/%s' % (HOST_IP,HOST_MASK))
  print('Gateway: \t%s' % HOST_GATEWAY)
  print('Fence Address: \t%s' % PM_ADDRESS)
  print('Move IP: \t%s/%s' % (HOST_MOVE_IP, HOST_MOVE_MASK))
  print('Bonding Mode: \t%s' % MODE)
  print

# Main script starts here - Get the total number of args passed to the script
total = len(sys.argv)

VERSION = params.Version(major='3', minor='5')
PM_ADDRESS=""
HOST_NAME=""
HOST_ADDRESS=""
HOST_IP=""
HOST_MASK=""
HOST_GATEWAY=""
HOST_MOVE_IP=""
HOST_MOVE_MASK=""
MODE=""
DOMAIN=""
ZONE=""
PASSWORD=""

if total  == 5:
  # All details are spcified as parameters on the command line
  print 'Script mode: Three parameters detected - not implememnted yet'
  print

  HOST_NAME = sys.argv[1]
  HOST_ADDRESS = sys.argv[2]
  HOST_MASK = sys.argv[3]
  HOST_GATEWAY = sys.argv[4]

  URL =           'https://rhevm.example.com:443/api'
  USERNAME =      'admin@internal'
  PASSWORD =      'redhat01'
  CA =        './rhevm-ca.crt'
  #lets just check that the certificates are in place
  while not os.path.isfile(CA):
    print "Missing certificate, attempting to get from the server"
    CERT = urllib2.urlopen("https://rhevm.example.com/ca.crt")
    output = open(CA,'wb')
    output.write(CERT.read())
    output.close()
  DC_NAME =       'default'
  CLUSTER_NAME =  'default'
  ROOT_PASSWORD = 'redhat01'

  summary()
#  sys.exit()

else:
  # Wrong number of parameters - dispaly usage
  print "%s params found" % total
  usage()
  sys.exit()

#################################################

# hardcode some values 

print('RHEV-M \t\t%s' % URL)
print('Certificate \t%s' %  CA)
print

# connect to the API or fail
try:
        api = API(url=URL, username=USERNAME, password=PASSWORD, ca_file=CA)
        print "Connected to %s successfully!" % api.get_product_info().name

except Exception as err:
        print "Connection failed: %s" % err



# -----------------------------------

try:
## This is where we could add fencing later
#    pm = params.PowerManagement()
#    pm.set_type('ipmilan')
#    pm.set_enabled(True)
#    pm.set_address(PM_ADDRESS)
#    pm.set_username('fencinguser')
#    pm.set_password('8Y#6smB+z63q')
#    pm.set_kdump_detection(True)

    if api.hosts.add(params.Host(name=HOST_NAME,
                     address=HOST_ADDRESS,
                     cluster=api.clusters.get(CLUSTER_NAME),
                     root_password=ROOT_PASSWORD)):
        print '* Host was added successfully'
        print '* Waiting for host to install and reach the Up status'
        while api.hosts.get(HOST_NAME).status.state != 'up':
            time.sleep(1)
        print "* Host is up"


## You can use this to put the host right innto main mode if you prefer
##
#    if api.hosts.get(HOST_NAME).deactivate():
#        print '* Setting Host to maintenance'
#        #print '* Waiting for host to reach maintenance status'
#        while api.hosts.get(HOST_NAME).status.state != 'maintenance':
#            time.sleep(1)
#        print '* Host is in maintenance mode'


except Exception as e:
    print 'Failed to install Host:\n%s' % str(e)


sys.exit(0)
# exiting here

