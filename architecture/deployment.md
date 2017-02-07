# Deployment




## Network Layout
On the layer1 host, there are six virtual networks configured via libvirt as separate virtual bridge devices:

1. **Services**: Any service which is visible in the demo scenario should be on this network, this includes all product GUIs and APIs. At the moment this network is NATed externally; it should also be possible to make it completely visible externally by implementing DNAT on the layer1 external nic.
2. **Guests**: RHEVM Guests and OpenStack Instance Floating IPs. This network can be connected to an external network (so RHEVM guests and OpenStack instances are available externally).
3. **Storage**: (currently not used) to separate storage traffic between hypervisors and storage backends
4. **Admin**: Used almost exclusively to provide admin access to layer2 hosts, e.g. via Ansible. Also used by RHEVM to connect to the RHEVH.
5. **RH OSP Provisioning**: Used by the RH OSP Director to boot/configure OSP nodes via PXE. Since it acts as control plane for all overcloud
nodes, it is also NATed to allow the controller/compute nodes to download images from the internet.
6. **RH OSP Internal**: Hosts various VLANs to separate out additional OSP networks (storage management, tenant, internal API), see https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux_OpenStack_Platform/7/html/Director_Installation_and_Usage/sect-Planning_Networks.html
