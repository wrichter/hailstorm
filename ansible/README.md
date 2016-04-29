# Automated rollout via Ansible
## Prerequisites
1. Install Ansible 2.0 on your local machine and run all the playbooks from there. Avoid Ansible 2.1 since we experienced some random problems running the playbooks with 2.1. Example for RHEL7:
 - # yum localinstall 'https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm'
 - # yum localinstall http://fedora.mirrors.romtelecom.ro/pub/epel/7/x86_64/a/ansible-2.0.1.0-2.el7.noarch.rpm
1. Clone this repository to your local machine, example:
 - $ mkdir -p ~/projects/hailstorm ; cd ~/projects/hailstorm ; git clone 'https://github.com/wrichter/hailstorm' git
1. Change the subscription pool ID, example:
 - # subscription-manager list --available
 - $ vim config/hailstorm_config.yml
1. Download the following binary files and put them either into the local ansible/binary directory or ensure they are already present on the layer1 host and configure the host_vars/layer1.yml paramter "layer1_binary_dir":
  - [RHEL-OSP overcloud binaries](https://access.redhat.com/downloads/content/191/ver=7/rhel---7/7/x86_64/product-software)
    - Overcloud image
    - Deployment ramdisk
    - Discovery ramdisk
  - [RHEL 7 binary DVD](https://access.redhat.com/downloads/content/69/ver=/rhel---7/7.2/x86_64/product-software)
  - [RHEL 6 binary DVD](https://access.redhat.com/downloads/content/69/ver=/rhel---6/6.7/x86_64/product-software)
1. Download the manifest for your Organization for the Satellite and copy the manifest-zip file to the local ansible/binary directory and rename it to manifest.zip
 - [ What is the workflow for generating a Satellite 5 Certificate or Satellite 6 manifest](https://access.redhat.com/articles/477863)
1. Change into the ansible directory, and copy or create the necessary ssh key pairs in the binary directory (the first one is used for the communication between the RHOSP-director and the layer1 host, the second to connect to the layer1 host from the outside). If you create new keys, ensure they are also added to the layer1's host root user as authorized key:
  - $ ssh-keygen -t rsa -f binary/undercloud
  - $ ssh-keygen -t rsa -f binary/hailstorm
1. If necessary, copy & adapt the hardware-driven configuration from the sample config/inf43.coe.muc.redhat.com.yml, especially
  - ansible_host: to the ip address or DNS name of your layer1 host (which is prepared with a minimal RHEL install).  
  - If no ssh keys are available, set the ansible_ssh_pass parameter to the hosts root password (see [ansible documentation](http://docs.ansible.com/ansible/intro_inventory.html))
1. If necessary, copy & adapt the software-driven configuration from the sample config/hailstorm_config.yml
1. If you encounter any issues please report it and edit this page if you think it can improve the process. 

## Running the playbook
Run all commands on your laptop from the ansible directory. Since the server might reboot when the playbook executes, running the playbook on the server is discouraged.

### Setting up the environment
Everything:
```
$ ansible-playbook -i hosts -e "@config/inf43.coe.muc.redhat.com.yml" -e "@config/hailstorm_config.yml" -e "@config/infrastructure_config.yml" create.yml
```
Only layer1 and OpenStack (see create.yml source code for available tags):
```
$ ansible-playbook -i hosts -e "@config/inf43.coe.muc.redhat.com.yml" -e "@config/hailstorm_config.yml" -e "@config/infrastructure_config.yml" create.yml --tags layer1,rhosp
```
### Tearing down the environment
Everything:
```
$ ansible-playbook -i hosts -e "@config/inf43.coe.muc.redhat.com.yml" -e "@config/hailstorm_config.yml" -e "@config/infrastructure_config.yml" destroy.yml
```
Only OpenStack:
```
$ ansible-playbook -i hosts -e "@config/inf43.coe.muc.redhat.com.yml" \
-e "@config/hailstorm_config.yml" -e "@config/infrastructure_config.yml" destroy.yml --tags rhosp
```

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
- **layer1_vms**: DEPRECATED - replaced by layer2_vms. Creates the virtual machines for an inventory group and installs a base RHEL via kickstart. Since the role is applied to the layer1 host, the name of the group is passed via variable name. This also means that all the variables/facts defined for the individual members of the group - i.e. the host that is to be instantiated - is not avaiable in the default scope. Most of the tasks iterate over the group members, so the host name is avialable as *item*. This means that you can access the actual host variables / facts via *hostvars[item].nameofvariable*.
- **layer2_vms**: Creates the virtual machines for an inventory group and installs a base RHEL via kickstart. Since it is applied to the ansible group itself, multiple VMs can be installed in parallel.
- **layer2_rhel**: configures the base RHEL installed in the previous step - a great place to put common configuration actions:
  - Subscribes/Unsubscribes the VM
  - Attaches it to a pool
  - Performs an upgrade to the latest package versions
  - Installs additional packages
  - Enables or disables services

#### Satellite  
- **layer2_satellite**: installs & configures Red Hat Satellite (runs katello installer, creates content views, activation keys, etc...)


#### OpenStack
- **layer1_rhosp**: configures the layer1 host to allow IPMI emulation
- **layer2_rhosp_director**: installs & configures Red Hat OpenStack Director (undercloud) and prepares "baremetal" nodes for installation of the RHOSP overcloud (runs for about 45 mins)
- **layer2_rhosp_overcloud**: deploys Red Hat OpenStack (overcloud) on the nodes prepared by director. This is still work in progress (runs for about 45 mins).


#### RHEV
- **layer1_rhev**: configures the layer1 host to provide an NFS share as storage domain
- **layer2_rhevm_engine**: installs & configures RHEV-Manager
- **layer2_rhevh**: registers the RHEL Hypervisor nodes in RHEV-Manager. Currently, the nodes typically fail on the first attempt and need to be reinstalled via the RHEV-Manager Web UI. Subsequent invocations of the playbook should --skip-tags layer1,vms,rhel,rhevh to ensure that the RHEVM installation tasks are not undone by previous ansible steps.
- **layer2_rhevm_storage**: configures the storage domain in RHEV-Manager via a RHEL-H host

All other roles are not yet usable.

### Network Connectivity

In order to access the virtual machines created on layer2, a tunneling mechanism is used. Ansible connects to the layer1 host and from there tunnels to the virtual machines via a dedicated admin network. See group_vars/layer2.yml to see what this tunneling mechanism actually looks like.

#### Accessing layer2 hosts via browser

- Log into the layer1 host using the following command to establish a SOCKS proxy on localhost port 1080
  ```
  $ ssh -i binary/hailstorm -D 1080 root@<NAME_OF_IP_OF_THE_LAYER1_HOST>
  ```
- Configure your browser to use a SOCKS proxy on localhost port 1080

#### Accessing layer2 host consoles via VNC
To debug installation processes, a connection to the VM console might be required. This can be achieved roughly by the follwoing approach:
- ensure that the VMs host variables contain the following property
  ```
  graphics: vnc,listen=0.0.0.0,password=redhat01
  ```
- log into your layer1 host and use the following command to determine which port the VNC console actually runs on (you can probably also specify a fixed port number; check the virt-install documentation)
  ```
  # virsh dumpxml <vm_name>
  ```
- log into the layer1 host again to port-forward a local port to the console (the second port number needs to be changed to the port number from the XML dump).
  ```
  $ ssh -i binary/hailstorm -L 5901:localhost:5901 root@<NAME_OF_IP_OF_THE_LAYER1_HOST>
  ```
- connect your VNC viewer to localhost:5901

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
