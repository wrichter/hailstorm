# Playbook structure

Similar to the architecture of [hailstorm](../Architecture.md) itself, a layered approach is chosen to implement the various virtual machines. A virtual machine typically consists of:
- a layer to create it (e.g. instantiating and kickstarting a KVM virtual machine, or instantiating a RHEV template or OSP instance)
- a layer to configure the operating system (e.g. subscribing it, enabling channels, installing packages, enabling/disabling services, etc.)
- one or more layers to perform VM-specific configurations (e.g. configuring specific services, running installers, etc...)

Each layer is implemented as Ansible role, i.e. encapsulates all the commands, templates, etc... in a subdirectory. These roles usually encapsulate multiple responsibilities: bringing up a VM/service/etc... (CREATE), a structured deletion where necessary (DESTROY), starting and stopping the VM/service, etc. The action to be performed is determined by a variable named "mode" which is set in the main playbook.


## How Hailstorm is configured

Hailstorm uses four different files to control its configuration:
- the ansible inventory ("hosts") which lists all the VMs that are being created
- config/hailstorm_config.yml which controls which software versions are being rolled out
- config/infrastructure_config.yml which specifies the network configuration and core services such as NTP or DNS provided by the layer1 host. The idea is that the hailstorm code could also be used to roll out the stack to a classic environment as long as the roles/networks described in this file are met through other means.
- config/<layer1_host_specific_file> which contains the layer1-host specific configuration. This can be the CPU/Memory configuration of the VMs (depending on the layer1 sizing), the filesystem layout (where qcow images and binaries are placed), HTTP proxy configuration, etc.

When rolling out hailstorm to a new machine, it is expected that you only need to add/adapt a layer1 host specific file and the rest can be left as-is.


## How VMs are configured (and what you need to do to instantiate one)

A VM's configuration (i.e. the variables and their values available during playbook run) is taken from multiple sources:
- the inventory file that describes what machines are there (supposed to be), what groups they belong to and (a limited amount of) configuration variables
- for each group the VM belongs to, the variables defined in the appropriately-named file in the group_vars directory
- (if existing) the variables defined for the specific VM in the appropriately-named file in the host_vars directory. Variables defined for a specific host overwrite the ones defined in the groups.

One of the design goals is to avoid redundancy in the configuration. Therefore, whenever possible, common configuration between multiple VMs is moved into a group the VMs then become member of. A second design goal is to avoid unecessary files, therefore  config files are only introduced where specifically required.

Every VM configuration includes:
- an ansible_host IP that is used to calculate all IP and MAC addresses on all networks
- number of (virtual) CPU cores
- single disk configuration (size, partition layout)
- NICs and network attachment
- (optionally) subscription pool
- (optionally) enabled repos
- (optionally) packages to be installed
- (optionally) firewall configuration
- (optionally) ntp service configuration

### NIC and network attachment configuration

You may elect to specify the NIC configuration (MAC address, IP address, etc...) directly in the host variable  "vm_nics". This is an array of maps with the keys "ip", "dev", "default_gw", "netmask", "mac" and "netname".

For most VMs, this information is calculated based on their ansible_host IP and the array "nic_attachments", which lists the networks each VM NIC is attached to. They are member of the group "accessible_via_admin_network" which in turn contains a formula to calculate "vm_nics" automatically. It also contains a formula to calculate the "ansible_host" variable to point to the NIC attached to the admin network.

The variables "default_route_via" and "name_service_via" specify on which network the default gateway and DNS service are provided by the layer1. The variable "ksdevice" specifies on which NIC the kickstart configuration will be provided (required for RHEL6).

For most VMs, the NIC attachments is similar: eth0 is attached to the "services" network where the component UIs and APIs are provided, eth1 is attached to the "admin" network and used for Ansible access and eth2 is connected to the storage network. These VMs are members of the group "niclayout-standard" which provides this configuration centrally.

### How to add a new VM (on layer 2)

Think of a name and add it to a (newly defined, if necessary) group in the inventory file. Ansible playbooks always operate on groups of machines, so a single VM might require a group of just that VM. Assign it a unique ansible_host IP BELOW the currently chosen numbers for RHOSP (since the RHOSP deployment roles assume all IP addresses above the one used for director to be freely available). In the inventory file, add the name to the following groups:
- to the RHEL6 or RHEL7 groups, depending on which OS you want installed
- to the "niclayout-standard" group, if you do not want to specify the NIC layout yourself
- to the "layer2" group (which will in turn make it a member of "accessible_via_admin_network")

If it is a new group, create stanzas in the create.yml, start.yml playbooks and in the reverse order in the stop.yml and destroy.yml playbooks with the following roles applied to the group:
- layer2_vms
- layer2_rhel
- layer2_rhel_reconfigure_dns
- any additional role that you create for this VM

## Understanding the playbooks
The playbooks (create.yml, destroy.yml - both in this directory) describe a sequence of "roles" to be applied to groups of machines. Each role in itself is a sequence of idempotent steps, i.e. they can be run more than one time without affecting the result.

### Inventory

The groups of machines referenced in the playbooks are defined in the [inventory](http://docs.ansible.com/ansible/intro_inventory.html) file "hosts" in this directory. These groups could for example be the virtual machines that make up OpenStack, RHEV, etc... Unless you are defining or changing a group of (virtual) machines, it is unlikely that you will need to change this file.

If a group consists only of a single machine (e.g. layer1), it has the same name as the machine itself. This might be confusing at first because it becomes clear only by knowing Ansible conventions that something refers to a single host versus a group (Hint: it is usually a group).

All playbooks assume that there is a single layer1 host in the layer1 group - they will fail / yield unexpected results if there are more than one layer1 host in the group.

### Configuration variables

For each (virtual) machine, a set of configuration properties is defined as follows: first, Ansible determines all groups a machine belongs to (based on the data in the inventory file). It then reads all corresponding properties files in the group_vars directory. Then, it reads the machine-specific configuration properties from the corresponding properties file in the host_vars directory, potentially overwriting a group property.

This approach allows to define common configurations on a group level with the ability to specify machine-specific configuration on a host level. Being written in YML, the properties can be complex data structures, i.e. structs and lists. You can name the properties (almost) any way you like, but be cautious prepending them with ansible_ - [such properties](http://docs.ansible.com/ansible/intro_inventory.html#list-of-behavioral-inventory-parameters) may be interpreted by the Ansible runtime itself. For example, ansible_host specifies the IP address that Ansible uses to connect to that specific machine via ssh.

### Roles

Roles are an Ansible concept which allows related tasks, templates, etc... to be grouped together, each in a separate subdirectory of roles. The entry point for each role is its tasks/main.yml file.

Ansible does not have a native concept of different actions such as "create the environment" or "tear down the environment" or "ensure that everything is reset after a demo" - all it does is run the tasks in the playbook / roles. This is why the roles' tasks/main.yml file is typically written to expect a variable named "mode" to be set to a specific verb such as "create" or "destroy". It then uses this variable to decide which actions to run, which are usually included as separate yml files.

The following roles exist:

#### Generic
- **common**: not a role in its own sense, rather a place where tasks, handlers or templates which are used in multiple roles can be stored and referenced.
- **layer1**: configures the layer1 host, network setup and services required by the layer2 VMs such as an export directory for kickstart files, NTP service, etc...
- **layer2_vms**: Creates the virtual machines for an inventory group and installs a base RHEL via kickstart. Since it is applied to the ansible group itself, multiple VMs can be installed in parallel.
- **layer2_rhel**: configures the base RHEL installed in the previous step - a great place to put common configuration actions:
  - Subscribes/Unsubscribes the VM
  - Attaches it to a pool
  - Performs an upgrade to the latest package versions
  - Installs additional packages
  - Enables or disables services
- **layer2_rhel_reconfigure_dns**: when the VMs are created, they use the layer1 IP address as DNS provider. This role changes the DNS configuration to point to a DNS service such as provided by satellite or IPA.

#### Satellite  
- **layer2_satellite**: installs & configures Red Hat Satellite (runs katello installer, creates content views, activation keys, etc...)
- **layer2_satellite_rhev**: configures the Satellite/RHEV integration after both have been brought up

#### IPA
- **layer2_ipa**: installs & configures IPA, creates user records, groups and DNS records

#### OpenStack
- **layer1_rhosp**: configures the layer1 host to allow IPMI emulation
- **layer2_rhosp_director**: installs & configures Red Hat OpenStack Director (undercloud) and prepares "baremetal" nodes for installation of the RHOSP overcloud (runs for about 45 mins)
- **layer2_rhosp_overcloud**: deploys Red Hat OpenStack (overcloud) on the nodes prepared by director. This is still work in progress (runs for about 45 mins).

#### RHEV
- **layer1_rhev**: configures the layer1 host to provide an NFS share as storage domain
- **layer2_rhevm_engine**: installs & configures RHEV-Manager
- **layer2_rhevh**: registers the RHEL Hypervisor nodes in RHEV-Manager. Currently, the nodes typically fail on the first attempt and need to be reinstalled via the RHEV-Manager Web UI. Subsequent invocations of the playbook should --skip-tags layer1,vms,rhel,rhevh to ensure that the RHEVM installation tasks are not undone by previous ansible steps.
- **layer2_rhevm_storage**: configures the storage domain in RHEV-Manager via a RHEL-H host
- **layer2_rhevm_ldap**: configures the RHEVM integration with IPA as LDAP provider

#### CloudForms
- **layer3_cloudforms_rhev**: uploads the CFME template and instantiates it on RHEV
- **layer3_cloudforms_config**: configures the CFME (indepenedent on where it has been instantiated)

#### OpenShift
- **layerX_openshift_all**: prepares all OpenShift machines (nodes, load balancer, etc...) for installation using the ansible playbook
- **layerX_openshift_node**: prepares all OpenShift nodes for installation (docker config, etc...)
- **layerX_openshift_installer**: installs OpenShift via ansible playbook and deploys the OpenShift infrastructure components (router, registry, etc...)
- **layerX_openshift_devops**: installs DevOpsTools (nexus, jenkins, git, ...) into a project named devops-tools
- **layerX_openshift_demo_monster**: installs JEE Demo App "Ticket Monster"



#### EFK
- **layer2_efk**: installs Kibana, ElasticSearch and fluentd based on the RHOSP8 optools
- **layer2_tdagent**: installs and configures fluentd (tdagent distribution) on other VMs

Any other role not described here are probably development artifacts and not yet usable.


## Coding Guidelines
All configuration should be
- Scripted via Ansible, all steps have names which explain what is going on
- Structured similarly to the existing Ansible project layout
- Idempotent: Repeatedly executable and always yieling the same result
- Flow control is in Ansible, i.e. try to avoid invoking scripts which in turn do many steps (which are then opaque to ansible)
- Skipping unnecessary steps (eg. discovering an action already took place instead of running it again if it takes a while)
- Driven by the inventory configuration & variables, i.e. when the inventory changes (a third hypervisor is added, or a hypervisor is removed), the script should not break but just do the right thing.
- not use the layer1 host directly as a delegate (e.g. via 'delegate_to: "{{ layer1_ansible_host }}"') but using the role names as described in config/infrastructure_config.yml
- Wrapped into a pull request which we can integrate back into the main project
