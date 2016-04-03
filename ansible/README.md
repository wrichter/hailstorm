# Automated rollout via Ansible
## Prerequisites
1. Clone this repository to your local machine
1. Download the following binary files and put them either into the local ansible/binary directory or ensure they are already present on the layer1 host and configure the host_vars/layer1.yml paramter "layer1_binary_dir":
  - <a href="https://access.redhat.com/downloads/content/191/ver=7/rhel---7/7/x86_64/product-software" target="_blank">RHEL-OSP overcloud binaries</a>
    - Overcloud image
    - Deployment ramdisk
    - Discovery ramdisk
  - <a href="https://access.redhat.com/downloads/content/69/ver=/rhel---7/7.2/x86_64/product-software">RHEL 7 binary DVD</a>
1. Change into the ansible directory, and copy or create the necessary ssh key pairs in the binary directory (the first one is used for the communication between the RHOSP-director and the layer1 host, the second to connect to the layer1 host from the outside):
  - $ ssh-keygen -t rsa -f binary/undercloud
  - $ ssh-keygen -t rsa -f binary/hailstorm
1. Adapt the host_vars/layer1.yml settings
  - rhel_iso_img: to the name of the RHEL 7 binary DVD ISO image
  - ansible_host: to the ip address or DNS name of your layer1 host (which is prepared with a minimal RHEL install).  
  - If no ssh keys are available, set the ansible_ssh_pass parameter to the hosts root password (see [ansible documentation](http://docs.ansible.com/ansible/intro_inventory.html))
1. Adapt the host_vars/rhosp-director.yml settings:
  - deploy_ramdisk_image
  - discovery_ramdisk_image
  - overcloud_image

## Running the playbook
Run all commands from the ansible directory

### Setting up the environment
Everything:
```
$ ansible-playbook -i hosts create.yml
```
Only layer1 and OpenStack (see create.yml source code for available tags):
```
$ ansible-playbook -i hosts create.yml --tags layer1,rhosp
```
### Tearing down the environment
Everything:
```
$ ansible-playbook -i hosts destroy.yml
```
Only OpenStack:
```
$ ansible-playbook -i hosts destroy.yml --tags rhosp
```
