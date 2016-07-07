# Automated rollout via Ansible

Learn more about the [playbook structure](Playbook.md).

## Running the playbook
Run all commands on your laptop from the ansible directory. Since the server might reboot when the playbook executes, running the playbook on the server is discouraged. Ensure that the playbook runs under an english locale, otherwise unexpected results may occur.

### Setting up the environment
Everything:
```
$ LC_LANG=C ansible-playbook -i hosts -e "@config/storm2.coe.muc.redhat.com.yml" \
-e "@config/hailstorm_config.yml" -e "@config/infrastructure_config.yml" create.yml
```
Only layer1 and OpenStack (see create.yml source code for available tags):
```
$ LC_LANG=C ansible-playbook -i hosts -e "@config/storm2.coe.muc.redhat.com.yml" \
-e "@config/hailstorm_config.yml" -e "@config/infrastructure_config.yml" create.yml --tags layer1,rhosp
```
### Tearing down the environment
Everything:
```
$ LC_LANG=C ansible-playbook -i hosts -e "@config/storm2.coe.muc.redhat.com.yml" \
-e "@config/hailstorm_config.yml" -e "@config/infrastructure_config.yml" destroy.yml
```
Only OpenStack:
```
$ LC_LANG=C ansible-playbook -i hosts -e "@config/storm2.coe.muc.redhat.com.yml" \
-e "@config/hailstorm_config.yml" -e "@config/infrastructure_config.yml" destroy.yml --tags rhosp
```

## Prerequisites
1. Install Ansible 2.0 or higher on your local machine and run all the playbooks from there. Example for RHEL7:
 - # yum localinstall 'https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm'
 - # yum localinstall http://fedora.mirrors.romtelecom.ro/pub/epel/7/x86_64/a/ansible-2.1.0.0-1.el7.noarch.rpm
1. Install Ansible 2.1 on RHEL 7 CSB (local install)
 - # yum-config-manager --add-repo=https://dl.fedoraproject.org/pub/epel/7/x86_64/
 - # wget -O /etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-7 https://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-7
 - # sudo rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-7
 - # sudo yum clean all
 - # sudo yum install -y python-devel libffi-devel openssl-devel gcc python-pip
 - # pip install --upgrade pip
 - # pip install paramiko
 - # pip install ansible
 - # ansible --version
    [mreinke@mreinke-t540 yum]# ansible --version
     ansible 2.1.0.0
     config file =
     configured module search path = Default w/o overrides

1. Clone this repository to your local machine, example:
 - $ mkdir -p ~/projects/hailstorm ; cd ~/projects/hailstorm ; git clone 'https://github.com/wrichter/hailstorm' git
1. Download the following binary files and put them either into the local ansible/binary directory or ensure they are already present on the layer1 host and configure the host_vars/layer1.yml paramter "layer1_binary_dir":
  - [RHEL-OSP overcloud binaries](https://access.redhat.com/downloads/content/191/ver=7/rhel---7/7/x86_64/product-software)
  - [RHEL 7 binary DVD](https://access.redhat.com/downloads/content/69/ver=/rhel---7/7.2/x86_64/product-software)
  - [RHEL 6 binary DVD](https://access.redhat.com/downloads/content/69/ver=/rhel---6/6.7/x86_64/product-software)
1. Download the manifest for your Organization for the Satellite and copy the manifest-zip file to the local ansible/binary directory and rename it to manifest.zip
 - [ What is the workflow for generating a Satellite 5 Certificate or Satellite 6 manifest](https://access.redhat.com/articles/477863)
1. Change into the ansible directory, and copy or create the necessary ssh key pairs in the binary directory (the first one is used for the communication between the RHOSP-director and the layer1 host, the second to connect to the layer1 host from the outside). If you create new keys, ensure they are also added to the layer1's host root user as authorized key:
  - $ ssh-keygen -t rsa -f binary/undercloud
  - $ ssh-keygen -t rsa -f binary/hailstorm
1. If necessary, copy & adapt the hardware-driven configuration from the sample config/storm2.coe.muc.redhat.com.yml, especially
  - ansible_host: to the ip address or DNS name of your layer1 host (which is prepared with a minimal RHEL install).  
  - If no ssh keys are available, set the ansible_ssh_pass parameter to the hosts root password (see [ansible documentation](http://docs.ansible.com/ansible/intro_inventory.html))
1. If necessary, copy & adapt the software-driven configuration from the sample config/hailstorm_config.yml
1. If you encounter any issues please report it and edit this page if you think it can improve the process.

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
