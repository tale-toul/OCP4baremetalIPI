﻿# Baremetal IPI Openshift 4 on libvirt KVM

## Table of contents

* [Introduction](#introduction)
* [Reference documentation](#reference-documentation)
* [Preparing the Hypervisor](#preparing-the-hypervisor)
* [Provisioning Network Based Architecture](#provisioning-network-based-architecture)
  * [Create the routable baremetal and provisioning networks in KVM](#create-the-routable-baremetal-and-provisioning-networks-in-kvm)
  * [Create the provisioning VM](#create-the-provisioning-vm) 
  * [Create the 3 empty master nodes](#create-the-3-empty-master-nodes)
  * [Create two empty worker nodes](#create-two-empty-worker-nodes)
  * [Install and set up vBMC in the physical node](#install-and-set-up-vbmc-in-the-physical-node) 
  * [Add firewall rules to allow the VMs to access the vbmcd service](#add-firewall-rules-to-allow-the-vms-to-access-the-vbmcd-service)
  * [Set up virtualization in the provisioning VM](#set-up-virtualization-in-the-provisioning-vm)
  * [Verify DNS resolution in the provisioning VM](#verify-dns-resolution-in-the-provisioning-vm) 
  * [Preparing the provisioning node for OpenShift Container Platform installation](#preparing-the-provisioning-node-for-openshift-container-platform-installation)
  * [Configure networking in the provisioning VM](#configure-networking-in-the-provisioning-vm)
  * [Get the pull secret Openshift installer and oc client](#get-the-pull-secret-openshift-installer-and-oc-client)
  * [Create the install config yaml file](#create-the-install-config-yaml-file)
  * [Install the Openshift cluster with BMC](#install-the-openshift-cluster-with-bmc) 
  * [Creating the infrastructure with terraform and ansible](#creating-the-infrastructure-with-terraform-and-ansible)
  * [Destroying the infrastructure in provisioning network design](#destroying-the-infrastructure-in-provisioning-network-design)
* [Troubleshooting the installation](#troubleshooting-the-installation)
  * [Connecting to the VMs with virt-manager](#connecting-to-the-vms-with-virt-manager) 
* [Creating the support VM](#creating-the-support-vm)  
  * [Set up the DNS server](#set-up-the-DNS-server)
  * [Set up the DHCP server](#set-up-the-dhcp-server)
* [Setup the physical host in AWS](#setup-the-physical-host-in-aws)
  * [Import the VM providing DHCP and DNS services](#import-the-vm-providing-dhcp-and-dns-services)
* [Redfish based architecture](#redfish-based-architecture)
  * [Prepare the physical host](#prepare-the-physical-host)
  * [Install sushy-tools](#install-sushy-tools)
  * [Setup sushy-tools](#setup-sushy-tools) 
  * [Start and test sushy tools](#start-and-test-sushy-tools) 
  * [Add firewall rules to allow access to sushy-tools](#add-firewall-rules-to-allow-access-to-sushy-tools) 
  * [Setup DNS service](#setup-dns-service) 
  * [Create the provisioning VM for redfish](#create-the-provisioning-vm-for-redfish)
  * [Create the empty cluster hosts](#create-the-empty-cluster-hosts) 
  * [Prepare the provision VM](#prepare-the-provision-vm) 
  * [Create the install configuration yaml file](#create-the-install-configuration-yaml-file)
  * [Install the Openshift-cluster with redfish](#install-the-openshift-cluster-with-redfish) 
  * [Set up UEFI boot mode](#set-up-uefi-boot-mode)
  * [Automatic deployment of infrastructure with ansible and terraform](#automatic-deployment-of-infrastructure-with-ansible-and-terraform)
  * [Destroying the infrastructure in redfish based architecture](#destroying-the-infrastructure-in-redfish-based-architecture)
* [External access to Openshift using NGINX](#external-access-to-openshift-using-nginx)
  * [Install and set up NGINX](#install-and-set-up-nginx)
  * [Install and set up NGINX with Ansible](#install-and-set-up-nginx-with-ansible)
  * [Configuring DNS resolution with dnsmasq](#configuring-dns-resolution-with-dnsmasq) 
  * [Accessing the cluster](#accessing-the-cluster)
* [Enable Internal Image Registry](#enable-internal-image-registry)
  * [Add Storage to the Worker Nodes](#add-storage-to-the-worker-nodes)
  * [Make the internal image registry operational](#make-the-internal-image-registry-operational)
* [Using a bonding interface as the main NIC](#using-a-bonding-interface-as-the-main-nic)
  * [Obtaining the NIC names](#obtaining-the-nic-names)
  * [Create the bonding interface during cluster installation](#create-the-bonding-interface-during-cluster-installation)
  * [Create the bonding interface after cluster installation](#create-the-bonding-interface-after-cluster-installation)
  * [Test the bonding interface](#test-the-bonding-interface)

## Introduction

This repository contains documentation and supporting files to deploy an Openshift 4 cluster using the IPI method in a **baremetal** cluster on libvirt/KVM virtual machines.

These instructions are intended to deploy tests environments and help understand the baremetal IPI installation method, it is not recommended to deploy a production cluster using the method described here.  As an additional benefit using libvirt/KVM reduces the cost compared to deploying the same cluster using real baremetal servers.

A powerful physical server is required, considering that it needs to host at least 6 VMs, each with its own requirements of memory, disk and CPU.  In case such server is not available, instructions are also provided to use a metal EC2 instance in AWS.

The documentation contains instructions on how to deploy the cluster with and without a provisioning network in the sections [Provisioning Network Based Architecture](#provisioning-network-based-architecture) and [Redfish based architecture](#redfish-based-architecture) respectively.

In addition to the manual instructions, automation using terraform and ansible is provided to deploy the infrastructure components both for [provisioning network based clusters (VMBC)](#creating-the-infrastructure-with-terraform-and-ansible) and for [non provisioning network based clusters (Redfish)](#automatic-deployment-of-infrastructure-with-ansible-and-terraform)

## Reference documentation

The official documentation explains in detail how to install an Openshift 4 cluster using the baremetal IPI method:
[Deploying installer-provisioned clusters on bare metal Overview](https://docs.openshift.com/container-platform/4.9/installing/installing_bare_metal_ipi/ipi-install-overview.html)

## Preparing the Hypervisor

The main two requirements for the physical host are:

* Contains enough compute resources (memory, CPU, disk) to support 6 or 7 virtual machines.  At least 64GB memory, 16 CPU cores and 500GB disk space is required.
* Supports libvirt/KVM virtualization 

The hypervisor's Operating System used in these instructions is RHEL 8, other linux distributions could be used but there will be some differences in the name of the packages installed, configuration files and options.

Refer to the section [Setup the physical host in AWS](#setup-the-physical-host-in-aws) to create a hypervisor host based on a metal instance in AWS.  

If a local server is going to be used, install and update the Operating System, register it with Red Hat (if using RHEL), and install the libvirt packages, check the section [Setup the physical host in AWS](#setup-the-physical-host-in-aws) for more details.


## Provisioning Network Based Architecture

The architecture design for this cluster is as follows:
* Uses libvirt/KVM based virtual machines.
* Uses both a bare metal network and a provisioning network.

![Provisioning network base architecture](images/arch1.png)
  
The physical server (AKA hypervisor) must support nested virtualization and have it enabled: [Using nested virtualization in KVM](https://docs.fedoraproject.org/en-US/quick-docs/using-nested-virtualization-in-kvm/)

Check if nested virtualization is supported, a value of 1 means that it is supported and enabled.
```
# cat /sys/module/kvm_intel/parameters/nested
1
```

Enable nested virtualization if it is not, [Enabling nested virtualization in KVM](https://docs.fedoraproject.org/en-US/quick-docs/using-nested-virtualization-in-kvm/#_enabling_nested_virtualization): 

* Shut down all running KVM VMs
```
# virsh list
# virsh shutdown <vm name>
```
* Unload the kvm_probe kernel module
```
# modprobe -r kvm_intel
```
* Reload the kernel module activating the nesting feature 
```
# modprobe kvm_intel nested=1
```
* To enable it permanently, add the following line to the /etc/modprobe.d/kvm.conf file:
```
options kvm_intel nested=1
```

Later the provisioning VM must also be configured to support nested virtualization.

### Create the routable baremetal and provisioning networks in KVM

The definition for the __routable__ network can be found in the file _net-chucky.xml_ in this repository.  It is a simple definition of a routable network with no DHCP, using the network address space 192.168.30.0/24

The definition for the __provisioning__ network can be found in the file net-provision.xml in this repository.  The file contains the definition of a non routable network with no DHCP, using the network address space 192.168.14.0/24

Create the networks with the commands:
```
# virsh net-define net-chucky.xml
# virsh net-define net-provision.xml
```
Start the networks and enable autostart so they will be started automatically next time

```
# virsh net-start chucky
# virsh net-autostart chucky

# virsh net-start provision
# virsh net-autostart provision

# virsh net-list 
 Name            State        Autostart   Persistent
-------------------------------------------------------------
 chucky          active     yes                   yes
 default         active     yes                   yes
 provision      active     yes                   yes
```

Check the network configuration in the host, new bridges should appear
```
# ip -4 a
# nmcli con show
```

### Create the provisioning VM

Get the qcow2 image for RHEL 8 from [https://access.redhat.com/downloads/](https://access.redhat.com/downloads/), click on __Red Hat Enterprise Linux 8__ and download __Red Hat Enterprise Linux 8.5 KVM Guest Image__

Copy the qcow2 image file to the libvirt images directory 
```
# cp rhel-8.5-x86_64-kvm.qcow2 /var/lib/libvirt/images/provision.qcow2
# chown qemu: /var/lib/libvirt/images/provision.qcow2
```

Restore the SELinux file tags:
```
# restorecon -R -Fv /var/lib/libvirt/images/provision.qcow2
```

Create the VM instance based on the above image with the following commands.  The MAC address is specified in the command line to make it predictable and easier to match to other configuration files:
```
# virt-customize -a /var/lib/libvirt/images/provision.qcow2 --root-password password:mypassword --uninstall cloud-init

# virt-install --name=provision --vcpus=4 --ram=24096 \
            --disk path=/var/lib/libvirt/images/provision.qcow2,bus=virtio,size=120 \
            --os-variant rhel8.5 --network network=provision \
           --cpu host-passthrough,cache.mode=passthrough \
            --network network=chucky,model=virtio,mac=52:54:00:9d:41:3c \
            --boot hd,menu=on --graphics vnc,listen=0.0.0.0 --noreboot \
            --noautoconsole --console pty,target_type=virtio
```

Resize the VM disk to match the size specified in the previous command.  Do this before starting the VM:
```
# qemu-img resize /var/lib/libvirt/images/provision.qcow2 120G
```

Complete the resizing from inside the VM
```
# virsh start provision
```

Connect to the provision VM.  There are two alternatives:
* Through the virtual console (to leave the console use CTRL+] )
```
# virsh console provision
```
* Through an ssh connection, only if the VM already has a valid network configuration, this may require the support VM with DNS and DHCP services running.
```
# virsh domifaddr provision --source arp
 Name           MAC address              Protocol         Address
-------------------------------------------------------------------------------
 vnet2          52:54:00:9d:41:3c        ipv4             192.168.30.10/0

$ ssh root@192.168.30.10

[root@localhost ~]# growpart /dev/vda 3
...
[root@localhost ~]# xfs_growfs /dev/vda3
...
[root@localhost ~]# df -Ph
...
[root@provision ~]# exit
```

### Create the 3 empty master nodes

These VMs don’t include an OS, it will be installed during OCP cluster deployment.

Create the empty disks
```
# for x in master{1..3}; do echo $x; \
   qemu-img create -f qcow2 /var/lib/libvirt/images/bmipi-${x}.qcow2 80G; \
   done
```

Update the SELinux file labels
```
# restorecon -R -Fv /var/lib/libvirt/images/bmipi-master*
```

Change the owner and group to qemu:
```
# for x in master{1..3}; do echo $x; chown qemu: \
    /var/lib/libvirt/images/bmipi-${x}.qcow2; done
```

Create the 3 master VMs using the empty disks created in the previous step.  These are connected to both the routable and the provisioning networks.  The order in which the NICS are created is important so that if the VM cannot boot from the disk, which is the case at first boot, it will try to do it through the NIC in the provisioning network where the DHCP and PXE services from ironiq will provide the necessary information. 

The MAC addresses for the routable and provisioning network NICs are specified so they match the ones defined in the external DHCP server and the install-config.yaml file, without the need to update the configuration of those services every time a new set of machines are created:

```
# for x in {1..3}; do echo $x; virt-install --name bmipi-master${x} --vcpus=4 \
   --ram=16384 --disk path=/var/lib/libvirt/images/bmipi-master${x}.qcow2,bus=virtio,size=80 \
   --os-variant rhel8.5 --network network=provision,mac=52:54:00:74:dc:a${x} \
   --network network=chucky,model=virtio,mac=52:54:00:a9:6d:7${x} \
   --boot hd,menu=on --graphics vnc,listen=0.0.0.0 --noreboot \
   --noautoconsole; done
```

### Create two empty worker nodes

These don’t include an OS, it will be installed during OCP cluster deployment.

First create the empty disks:
```
# for x in worker{1..2}; do echo $x; \
   qemu-img create -f qcow2 /var/lib/libvirt/images/bmipi-${x}.qcow2 80G; done
```

Update the SELinux file labels
```
# restorecon -R -Fv /var/lib/libvirt/images/bmipi-worker*
```
Change the owner and group to qemu:
```
# for x in worker{1..2}; do echo $x; chown qemu: \
   /var/lib/libvirt/images/bmipi-${x}.qcow2; done
```

Create the 2 worker nodes using the empty disks created in the previous step.  These are connected to both the routable and the provisioning networks.  The order in which the NICS are created is important so that if the VM cannot boot from the disk, which is the case at first boot, it will try to do it through the NIC in the provisioning network first, where the DHCP and PXE services from ironiq will provide the necessary information. 

The MAC addresses for the routable and provisioning network NICs are specified so they can easily match the ones added to the external DHCP and install-config.yaml file, without the need to update the configuration of those services every time a new set of machines are created:
```
# for x in {1..2}; do echo $x; virt-install --name bmipi-worker${x} --vcpus=4 \
   --ram=16384 --disk \
   path=/var/lib/libvirt/images/bmipi-worker${x}.qcow2,bus=virtio,size=80 \
   --os-variant rhel8.5 --network network=provision,mac=52:54:00:74:dc:d${x} \
   --network network=chucky,model=virtio,mac=52:54:00:a9:6d:9${x} \
   --boot hd,menu=on --graphics vnc,listen=0.0.0.0 --noreboot \
   --noautoconsole; done
```

Check that all VMs are created:
```
# virsh list –all
```

### Install and set up vBMC in the physical node

The next steps must be taken in the physical host.

Install the following packages

```
# dnf install gcc libvirt-devel python3-virtualenv ipmitool
```
Create a python virtual environment to install vBMC
```
# virtualenv-3 virtualbmc

# . virtualbmc/bin/activate
```

Install virtual BMC in the python virtual environment:
```
(virtualbmc) # pip install virtualbmc
```

Start the vbmcd daemon in the python virtual environment.  In the Openshift cluster is rebooted after installation, this service must be started before starting the cluster nodes:
```
(virtualbmc) # ./virtualbmc/bin/vbmcd
```

Find the IP address of the bridge connected to the routable network (chucky) in the physical machine:
```
# virsh net-dumpxml chucky
…
  <bridge name='virbr2' stp='on' delay='0'/>
  <mac address='52:54:00:6a:56:bc'/>
  <ip address='192.168.30.1' netmask='255.255.255.0'>
  </ip>
</network>
```
Can also be checked with:
```
# ip -4 a show dev chucky
5: chucky: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
    inet 192.168.30.1/24 brd 192.168.30.255 scope global chucky
```

Add the master and worker node VMs to virtual BMC, use the IP obtained before to contact the vbmcd daemon and a unique port for each VM, the ports are arbitrary but should be above 1024.  The name of the node is the one shown in the output of `virsh list –all` command.  A username and password is associated to each node that must be used later to control the VMs; in this case all nodes use the same username/password combination.  Keep in mind that the ipmi protocol used by BMC is not encrypted or secured in any way:
```
(virtualbmc) # for x in {1..3}; do vbmc add --username admin --password secreto \
                          --port 700${x} --address 192.168.30.1 bmipi-master${x}; done

(virtualbmc) # for x in {1..2}; do vbmc add --username admin --password secreto \
                          --port 701${x} --address 192.168.30.1 bmipi-worker${x}; done
```

Check that the VMs are accepted:
```
(virtualbmc) # vbmc list
+---------------+--------+--------------+------+
| Domain name   | Status | Address      | Port |
+---------------+--------+--------------+------+
| bmipi-master1 | down   | 192.168.30.1 | 7001 |
| bmipi-master2 | down   | 192.168.30.1 | 7002 |
| bmipi-master3 | down   | 192.168.30.1 | 7003 |
| bmipi-worker1 | down   | 192.168.30.1 | 7011 |
| bmipi-worker2 | down   | 192.168.30.1 | 7012 |
+---------------+--------+--------------+------+
```

Start a virtual BMC service for every virtual machine instance:
```
(virtualbmc) # for x in {1..3}; do vbmc start bmipi-master${x}; done

(virtualbmc) # for x in {1..2}; do vbmc start bmipi-worker${x}; done
```

The status in the vbmc list command changes to running.  This is not the VM running but the BMC service for that VM
```
(virtualbmc) # vbmc list
+---------------+---------+--------------+------+
| Domain name   | Status  | Address      | Port |
+---------------+---------+--------------+------+
| bmipi-master1 | running | 192.168.30.1 | 7001 |
| bmipi-master2 | running | 192.168.30.1 | 7002 |
| bmipi-master3 | running | 192.168.30.1 | 7003 |
| bmipi-worker1 | running | 192.168.30.1 | 7011 |
| bmipi-worker2 | running | 192.168.30.1 | 7012 |
+---------------+---------+--------------+------+
```

Verify Power status of VM's.  These commands use the user/password and IP/port defined before for each node:
```
(virtualbmc) # for x in {1..3}; do ipmitool -I lanplus -U admin -P secreto \
                    -H 192.168.30.1 -p 700${x} power status; done
Chassis Power is off
Chassis Power is off
Chassis Power is off

(virtualbmc) # for x in {1..2}; do ipmitool -I lanplus -U admin -P secreto \
                          -H 192.168.30.1 -p 701${x} power status; done
Chassis Power is off
Chassis Power is off
```
The KVM VMs can now be controlled through the vBMC server using the ipmi protocol.

### Add firewall rules to allow the VMs to access the vbmcd service. 

In order for the bootstrap server to be able to start the KVM VMs a rule must be added to the physical host firewall allowing connections from machines in the virtual networks chucky and provision to reach the ports defined earlier for each VM in vBMC

These rules are created in the physical host:
```
# firewall-cmd --add-port 7001/udp --add-port 7002/udp --add-port 7003/udp \
   --add-port 7011/udp --add-port 7012/udp --zone=libvirt --permanent
# firewall-cmd --reload
# firewall-cmd --list-all --zone libvirt
```
### Set up virtualization in the provisioning VM 

Further details at [Set up nested virtualization in the provisioning VM](https://docs.fedoraproject.org/en-US/quick-docs/using-nested-virtualization-in-kvm/#proc_configuring-nested-virtualization-in-virt-manager)

The support VM with DHCP and DNS services must be setup and running at this point.  For details on how to create this VM check the section [Creating the support VM](#creating-the-support-vm)  

If it is not running, start the provision VM
```
# virsh start provision 
```

Connect from the physical host to the provision VM using the IP defined in the DHCP server for that host
```
$ ssh root@192.168.30.10
```

Register the provision VM with Red Hat
```
# subscription-manager register --user <rh user>
# subscription-manager list --available
# subscription-manager attach --pool=8a589f...
```

Install the host virtualization software:
```
# dnf group install virtualization-host-environment
```

Update the Operating System
```
# dnf update
# reboot
```
Verify that the provisioning VM has virtualization correctly set up.  The last 2 warnings are not relevant, they also appear when running the same command in the physical host:
```
provision # virt-host-validate
  QEU: Checking for hardware virtualization                                     : PASS
  QEU: Checking if device /dev/kvm exists                                       : PASS
  QEU: Checking if device /dev/kvm is accessible                                : PASS
  QEU: Checking if device /dev/vhost-net exists                                 : PASS
  QEU: Checking if device /dev/net/tun exists                                   : PASS
  QEU: Checking for cgroup 'cpu' controller support                             : PASS
  QEU: Checking for cgroup 'cpuacct' controller support                         : PASS
  QEU: Checking for cgroup 'cpuset' controller support                          : PASS
  QEU: Checking for cgroup 'memory' controller support                          : PASS
  QEU: Checking for cgroup 'devices' controller support                         : PASS
  QEU: Checking for cgroup 'blkio' controller support                           : PASS
  QEU: Checking for device assignment IOU support                               : WARN (No ACPI DAR table found, IOU either disabled in BIOS or not supported by this hardware platform)
  QEU: Checking for secure guest support                                        : WARN (Unknown if this platform has Secure Guest support)
```

### Verify DNS resolution in the provisioning VM

Test that the DNS names of all nodes can be resolved from the provisioning VM
```
[root@provision ~]# for x in {1..3}; do dig master${x}.ocp4.tale.net +short; done
192.168.30.20
192.168.30.21
192.168.30.22
[root@provision ~]# for x in {1..2}; do dig worker${x}.ocp4.tale.net +short; done
192.168.30.30
192.168.30.31
```

### Preparing the provisioning node for OpenShift Container Platform installation

Further details can be obtained from the [official documentation](https://docs.openshift.com/container-platform/4.9/installing/installing_bare_metal_ipi/ipi-install-installation-workflow.html#preparing-the-provisioner-node-for-openshift-install_ipi-install-installation-workflow)

Log in to the provisioning VM
```
# virsh domifaddr provision --source arp
 Name       MAC address          Protocol     Address
-------------------------------------------------------------------------------
 vnet1      52:54:00:9d:41:3c    ipv4         192.168.30.10/0

# ssh root@192.168.30.10
```
Create a non privileged user and provide that user with sudo privileges::
```
# useradd kni
# passwd kni
# echo "kni ALL=(root) NOPASSWD:ALL" | tee -a /etc/sudoers.d/kni
# chmod 0440 /etc/sudoers.d/kni
```

Make sure the firewalld service is enabled and running:
```
# systemctl enable firewalld --now
# systemctl status firewalld
```
Enable the http service in the firewall.  Add the rules:
```
$ sudo firewall-cmd --zone=public --add-service=http --permanent
$ sudo firewall-cmd --reload
```

Create an ssh key for the new user:
```
# su - kni -c "ssh-keygen -t ed25519 -f /home/kni/.ssh/id_rsa -N ''"
```

Log in as the new user on the provisioner node:
```
# su - kni
```

Install the following required packages, some may already be installed:
```
$ sudo dnf install libvirt qemu-kvm mkisofs python3-devel jq ipmitool
```

Modify the user to add the libvirt group to the newly created user:
```
$ sudo usermod --append --groups libvirt kni
$ virsh -c qemu:///system list
```

Start and enable the libvirtd service, if it has not been done before:
```
$ sudo systemctl enable libvirtd --now
$ sudo systemctl status libvirtd
```

Create the default storage pool and start it:
```
$ virsh -c qemu:///system pool-define-as --name default --type dir --target /var/lib/libvirt/images 

$ virsh -c qemu:///system pool-list --all
 Name          State          Autostart
-----------------------------------------
 default           inactive   no

$ virsh -c qemu:///system pool-start default
Pool default started

$ virsh -c qemu:///system pool-autostart default
Pool default marked as autostarted

$ virsh -c qemu:///system pool-list --all --details
 Name          State        Autostart
--------------------------------------------
 default          active   yes
```

### Configure networking in the provisioning VM

The following network configuration allows the bootstrap VM, created as a nested virtual machine inside the provisioning host, to be reachable from outside the provisioning host.  

The bootstrap VM is connected to the routable and provision bridges (chucky and provision) directly which allows it to get IPs in the external networks and therefore be accessible from outside the provisioning VM

Do this from a local terminal or the connection will be dropped half way through the configuration process.

Apply these instructions Even if a network connection is already active and working.
```
# virsh console provision
# nmcli con show
NAME                                 UUID                                                                 TYPE              DEVICE
Wired connection 2  1af5c70e-3d13-3ca7-92a9-e2582e653372  ethernet  eth1   
virbr0                  b1ff2de8-0b3f-4d60-bb91-8b03078fc155               bridge            virbr0
Wired connection 1  3defbd59-64c2-3806-947a-c1be05a4752e  ethernet  --


# ip -4 a
…
3: eth1: <BROADCAST,ULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
        inet 192.168.30.10/24 brd 192.168.30.255 scope …
4: virbr0: <NO-CARRIER,BROADCAST,ULTICAST,UP> mtu 1500 qdisc noqueue state DOWN group default qlen 1000
        inet 192.168.122.1/24 brd 192.168.122.255 scope global virbr0
```

Set up the connection to the routable network
```
# nmcli con down "Wired connection 2"
Connection 'Wired connection 2' successfully deactivated …

# nmcli con delete "Wired connection 2"


# nmcli con add ifname baremetal type bridge con-name baremetal
# nmcli con add type bridge-slave ifname eth1 master baremetal
Connection 'bridge-slave-eth1' … successfully added.
```

Now the dhcp client should assign the same IP to the new bridge interface, this may take a couple minutes, if not, reactivate the connection:
```
# nmcli con down baremetal
# nmcli con up baremetal
```

Next the provisioning network interface is reconfigured, this can be done from an ssh connection to the provisioning host since the provisioning network interface does not affect that.
```
# nmcli con down "Wired connection 1"
Connection 'Wired connection 1' successfully deactivated …
# nmcli con delete "Wired connection 1"
Connection 'Wired connection 1' … successfully deleted.

# nmcli con add type bridge ifname provision con-name provision
Connection 'provision' … successfully added.
# nmcli con add type bridge-slave ifname eth0 master provision
Connection 'bridge-slave-eth0' … successfully added.
```

Assign an IPv4 address to the provision bridge.  Make sure the IP used is in the provisioning network but outside the DHCP range defined in the install-config.yaml file:
```
# nmcli con mod provision ipv4.addresses 192.168.14.14/24 \
    ipv4.method manual
```

Activate the provision network connection:
```
# nmcli con down provision
# nmcli con up provision
```

Check out the results
```
$ nmcli con show provision
$ ip -4 a
```

### Get the pull secret Openshift installer and oc client

In the provisioning VM, as the kni user, get a pull secret from [Red Hat](https://console.redhat.com/openshift/install/metal/user-provisioned), and paste it into a file in the kni user home directory.
```
$ vim pull-secret.txt
```

Download the Openshift client and installer.  The version to be installed can be any of the version numbers defined as directory names at [https://mirror.openshift.com/pub/openshift-v4/clients/ocp/](https://mirror.openshift.com/pub/openshift-v4/clients/ocp/).  To use the latest stable version for a particular minor version use the directory name `stable-<minor version`, in the following example the latest 4.9 version is used.
```
$ export VERSION=stable-4.9
$ export RELEASE_IMAGE=$(curl -s https://mirror.openshift.com/pub/openshift-v4/clients/ocp/$VERSION/release.txt | grep 'Pull From: quay.io' | awk -F ' ' '{print $3}')
$ export cmd=openshift-baremetal-install
$ export pullsecret_file=~/pull-secret.txt
$ export extract_dir=$(pwd)
$ echo $extract_dir
$ curl -s https://mirror.openshift.com/pub/openshift-v4/clients/ocp/$VERSION/openshift-client-linux.tar.gz | tar zxvf - oc
$ sudo cp oc /usr/local/bin
$ oc adm release extract --registry-config "${pullsecret_file}" --command=$cmd --to "${extract_dir}" ${RELEASE_IMAGE}
```

### Create the install config yaml file

The provided install-config.yaml file in this repository at **provisioning/install-config.yaml** contains a mostly functional template for installing the Openshift 4 cluste.  In particular, the IP addresses and networks, ports and MAC addresses match those used in other parts of this documentation.  The cluster name and DNS domain also match the ones used in the section [Creating the support VM ](#creating-the-support-vm)

Review the install-config.yaml file provided and add the pull secret downloaded in the previous section and an ssh public key, the one created for the kni user earlier for example, at the end of the file.

Check the [reference documentation](https://docs.openshift.com/container-platform/4.9/installing/installing_bare_metal_ipi/ipi-install-installation-workflow.html#configuring-the-install-config-file_ipi-install-installation-workflow) for details.

### Install the Openshift cluster with BMC

Create a directory and copy the install-config.yaml file into it.  This is done to make sure a copy of the install-cofig.yaml file survives the installation. The surviving copy is the one kept in the main directory:
```
$ mkdir ocp4
$ cp install-config.yaml ocp4/
```

Ensure all bare metal nodes are powered off, the following commands are run on the physical host:

Check the control plane hosts:
```
# for x in {1..3}; do ipmitool -I lanplus -U admin -P secreto \
                    -H 192.168.30.1 -p 700${x} power status; done
Chassis Power is off
Chassis Power is off
Chassis Power is off
```
Check the compute hosts:
```
# for x in {1..2}; do ipmitool -I lanplus -U admin -P secreto \
                          -H 192.168.30.1 -p 701${x} power status; done
Chassis Power is off
Chassis Power is off
```
If a previous failed installation happened, remove old bootstrap resources if any are left over from a previous deployment attempt.  The error about missing volume vda is normal, nothing to worry about.
```
$ ./openshift-baremetal-install destroy cluster --dir ocp4


$ sudo virsh list
 Id   Name                       State
--------------------------------------
 1        ocp4-876p7-bootstrap   running


$ sudo virsh destroy ocp4-876p7-bootstrap
Domain ocp4-876p7-bootstrap destroyed


$ sudo virsh undefine ocp4-876p7-bootstrap --remove-all-storage
error: Storage pool 'ocp4-876p7-bootstrap' for volume 'vda' not found.
Domain ocp4-876p7-bootstrap has been undefined
```
Finally run the installer from the provisioning host:
```
$ ./openshift-baremetal-install create cluster --dir ocp4/ 
```

## Creating the infrastructure with terraform and ansible

The infrasctucture required to deploy the Openshift cluster can be created with the [terraform](https://www.terraform.io/downloads.html) templates and [ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html) playbooks provided in this repository.

There are several configuration options to adapt the resulting infrastructure to the particular requirements of the user.

For these instructions to run successfully [terraform](https://www.terraform.io) and [ansible](https://www.ansible.com) must be installed and working in the controlling host.

* Go to the [Terraform directory](Terraform/README.md) and follow the instructions to deploy the metal instance and associated components in AWS.

* Go to the [Ansible directory](Ansible/README.md) and follow the instructions in the sections: [Subscribe hosts with Red Hat](Ansible/README.md#subscribe-hosts-with-red-hat), [Add the common ssh key](Ansible#add-the-common-ssh-key) and [Running the playbook to configure the metal EC2 instance](Ansible#running-the-playbook-to-configure-the-metal-ec2-instance)

* (Optionall) Get more insights into the libvirt resources, run [virt manager](https://virt-manager.org/) on the localhost as explained in [Connecting to the VMs with virt-manager](#connecting-to-the-VMs-with-virt-manager).  The configuration tasks have been executed by the **setup_metal** ansible playbook so only the connection command needs to be run.

* Go to the [Terraform/libvirt directory](Terraform/libvirt/README.md) and follow the instructions to create the libvirt/KVM resources.

* Go back to the [Ansible directory](Ansible/README.md) and follow the instructions in sections [Set up KVM instances](Ansible#set-up-kvm-instances) and [Running the playbook for libvirt VMs](Ansible#running-the-playbook-for-libvirt-vms)

* SSh into the provisioning node as the kni user. Make sure to [add the ssh key to the shell](Ansible#add-the-common-ssh-key). The connection can be stablish [using the EC2 instance as a jump host](Ansible#running-tasks-via-a-jumphost-with-ssh)

     The home directory of the kni user contains all necessary files to run the Openshift installation, and all the required infrastructure should be in place and ready.
```
$ ssh -J ec2-user@3.219.143.250  kni@192.168.30.10
```

* Review the install-config.yaml file and add or modify the configuratin options.

* Copy the install-config.yaml file into the directory with the name of the cluster

* Run the [Openshift installer](#install-the-openshift-cluster-with-bmc)

### Destroying the infrastructure in provisioning network design

There are three levels of instrastructure that can be eliminated: The Openshift cluster; the libvirt resources and the AWS resouces.

To destroy the Openshift cluster connect to the provisioning host with the kni user and run a command like:
```
provision $ ./openshift-baremetal-install destroy cluster --dir ocp4
```

To destroying the libivrt resources if they were created with terraform, go to the **Terraform/libvirt** directory in the controlling host and run a command with the same options that were used to create them, but using the **destroy** subcommand instead.
```
$ terraform destroy -var-file monaco.vars
```
To destroy the libvirt resources manually, connect to the EC2 instance and destroy and undefine all libvirt resources: VMs, volumes, networks, storage pool,etc.  Check the list of [created resources](Terraform/libvirt#created-resources)   Check the `virsh --help` for details on how to do it.

Destroying the libvirt resources will also destroy the Openshift cluster if it was still running.

To destroy the AWS resources if they were created with terraform, go to the **Terraform** directory in the controlling host and run a command with the same options that were used to create them, but using the **destroy** subcommand:
```
terraform destroy -var="region_name=us-east-1" -var="ssh-keyfile=baremetal-ssh.pub" -var="instance_type=c5.metal"
```
If a variables file was used:
```
terraform destroy -var-file yenda.vars
```

To destroy the AWS resources manually, go to the AWS web console and remove the EC2 instance, the internet gateway, routing table, elastic IP, etc.  Check the list of [created resources](Terraform#resources-created)

Destroying the AWS resources will cause the destruction of the libvirt resources and Openshift cluster that may exist inside the EC2 instance.

## Troubleshooting the installation

To obtain the IP of any of the VMs you can run the following command in the AWS metal instance. In the example, the provision VM's IP is obtained:
```
$ virsh -c qemu:///system domifaddr provision --source arp
 Name       MAC address          Protocol     Address
-------------------------------------------------------------------------------
 vnet16     52:54:00:9d:41:3c    ipv4         192.168.30.10/0
```
For the provision and support VMs, you can get the IP from the terraform output:
```
$ cd Terraform/libvirt
$ terraform output provision_host_ip
"192.168.30.10"
$ terraform output support_host_ip
"192.168.30.3"
```
If you need the IP for the provision or support VMs before they are running or even created, check the value in the file **Terraform/libvirt/input-vars.tf**

Check the installation log in the provisioning host as the kni user:
```
$ tail -f ocp4/.openshift_install.log
```
Check if the bootstrap VM has been created and is running in the provisioning node (nested virtualization):
```
[kni@provision ~]$ sudo virsh list --all
 Id        Name                            State
--------------------------------------------------------
 1        ocp4-x7578-bootstrap   running
```

If the bootstrap is running, ssh into it and check the logs there.

To get the bootstrap VM IP run the following commands in the provisioning VM:
```
$ sudo virsh list
$ sudo virsh domifaddr <bootstrap name> --source arp
```
Connect to the bootstrap node using the core user, the ssh certificate that was used in the install-config.yaml file and the IP obtained in the previous step.  The connection can be initiated from the physical host or the provisioning VM:
```
# ssh -i .ssh/bmipi core@192.168.30.80
```

Check the pods running in the bootstrap VM
```
# sudo podman ps
```


Check the logs in the ironic pods
```
[core@localhost ~]$ sudo podman logs -f ironic-inspector
[core@localhost ~]$ sudo podman logs -f ironic-conductor
[core@localhost ~]$ sudo podman logs -f ironic-api
```

Run ipmitool from the ironic-conductor pod
```
$ sudo podman exec -ti ironic-conductor /bin/bash
[root@localhost /]# ipmitool -I lanplus -U admin -P secreto -H 192.168.30.1 \
-p 7000 power status           
Error: Unable to establish IPI v2 / RCP+ session
The same command from the provisioning host does not work either.
However that command does work from the physical host so it looks like this is a firewall issue.
```

To use tcpdump inside the bootstrap machine check the following [documentation section](https://docs.openshift.com/container-platform/4.9/support/gathering-cluster-data.html#about-toolbox_gathering-cluster-data) and [KCS](https://access.redhat.com/articles/4365651)


The provisioning network configuration can be checked with the following command:
```
$ oc get provisioning -o yaml
```


The baremetal hosts configuration can be retrieved with the following command:
```
$ oc -n openshift-machine-api get bmh
```

### Connecting to the VMs with virt-manager

These instructions can be applied when the physical host is an AWS metal instance, for other cases, adapt accordingly.

In the AWS metal instance:

* Add the ec2-user to the libvirt group:
```
$ sudo usermod -a -G libvirt ec2-user
$ virsh -c qemu:///system list
```

* Add firewall rules in the physical host to connect to the VNC ports. Better to use a range of ports
```
$ sudo firewall-cmd --add-port 5900-5910/tcp --zone=public  --permanent
$ sudo firewall-cmd --reload
$ sudo firewall-cmd --list-all --zone public
```

Add the same ports above to the security rule in the AWS instance

Connect to libvirt daemon from the local host using virt-manager.  The command uses the public IP address of the EC2 instance and the _private_ part of the ssh key injected into the instance with terraform.  The ssh key file should be at ~/.ssh directory:
```
$ virt-manager -c 'qemu+ssh://ec2-user@44.200.144.12/system?keyfile=ssh.key'
```
This command may take a couple minutes to stablish the connection before actually showing the virt-manager interface.

![Virt manager](images/virt-manager.png)

In the “Display VNC” section of the VM hardware details in virt-manager, the field Address must contain the value __All interfaces__.  This can be set at VM creation with virt-manager as the examples in this document show, using the option __--graphics vnc,listen=0.0.0.0__.

## Creating the support VM

This VM will run the DHCP and DNS services.  It is based on the rhel 8 qcow2 image

Copy the qcow2 image file to the libvirt images directory 

```
# cp rhel-8.5-x86_64-kvm.qcow2 /var/lib/libvirt/images/dhns.qcow2
```

Create the VM instance based on the above image with the following commands:
```
# virt-customize -a /var/lib/libvirt/images/dhns.qcow2 \
    --root-password password:mypassword --uninstall cloud-init

# virt-install --name=dhns --vcpus=2 --ram=1536 \
--disk path=/var/lib/libvirt/images/dhns.qcow2,bus=virtio,size=40 \
--os-variant rhel8.5 --network network=chucky,model=virtio --boot hd,menu=on \
--graphics vnc,listen=0.0.0.0 --noreboot --noautoconsole --console pty,target_type=virtio

# qemu-img resize /var/lib/libvirt/images/dhns.qcow2 40G
# qemu-img info /var/lib/libvirt/images/dhns.qcow2
# virsh start dhns
# virsh console dhns
[root@localhost ~]# growpart /dev/vda 3
# xfs_growfs /dev/vda3
```

Set up IP configuration.  Networking will be reconfigured during the setup of the VM, but for now it requires the ability to install packages.

```
# nmcli con delete "Wired connection 1"
# nmcli con add con-name eth0 type ethernet \
    ifname eth0 autoconnect yes ip4 192.168.30.3 gw4 192.168.30.1
# nmcli con mod eth0 +ipv4.dns 192.168.100.1
# nmcli con up eth0
```

Subscribe the VM to Red Hat

```
# subscription-manager register --user <rh user>
# yum update
# reboot
```

Assign a permanent hostname
```
# hostnamectl set-hostname dhns.tale.net
```
Install the packages for DNS and DHCP services
```
# yum install bind bind-utils dhcp-server
```

### Set up the DNS server

Start and enable named:
```
# systemctl enable --now named
```

Use the configuration files in the **support-files** directory in this repository as a base for the configuraion.  Keep in mind that if these files are modified, the configuration in other parts of the deployment process will be affected

```
/etc/named.conf
/etc/named/tale.zones
/var/named/tale.net.zone
/var/named/tale.net.rzone
```

Change the owner of the last two files:
```
# chown named:named /var/named/tale.net.zone /var/named/tale.net.rzone
```

Reload the bind named:
```
# systemctl reload named
```

Check for errors:
```
# journalctl -u named -e
```

Verify forward and reverse resolution:
```
# dig @192.168.30.3 master1.ocp4.tale.net +short
# dig @192.168.30.3 -x 192.168.30.3 +short
```

Update the network configuration to reflect the new DNS server
```
# nmcli con mod eth0 +ipv4.dns 127.0.0.1 -ipv4.dns 192.168.100.1 \
   +ipv4.dns-search tale.net
```

Restart the network connection, this must be done on a local connection because the network will go down after the first command:
```
# nmcli con down eth0
# nmcli con up eth0
```

### Set up the DHCP server

Use the configuration files in the support-files directory in this repository as a base for the configuraion.  Keep in mind that if these files are modified, the configuration in other parts of the deployment process will be affected

/etc/dhcp/dhcpd.conf

Enable and start the dhcpd service
```
# systemctl enable dhcpd –now
```

After any modification to the configuration file restart the dhcpd daemon and check the log messages it generates:
```
# systemctl restart dhcpd
# journalctl -u dhcpd -e
```

## Setup the physical host in AWS

This section describes how to set up a metal instance in AWS to be used as the physical server (AKA hypervisor) in which the KVM virtual machines will run.

The same process described here can be automated with terraform and ansible, check the [Terraform](https://github.com/tale-toul/OCP4baremetalIPI/blob/main/Terraform) and [Ansible](https://github.com/tale-toul/OCP4baremetalIPI/blob/main/Ansible) directories for futher instructions.

In the AWS web site go to __EC2__ -> __Instances__ -> __Launch Instances__

Select the AMI __Red Hat Enterprise Linux 8 (HVM), SSD Volume Type__, 64 bit (x86) architecture.

In the Instance type page select __c5n.metal__ (192GB RAM, 72 vCPUs) -> __Configure Instance Details__

Select the VPC and subnet where the host will be deployed.  The subnet must have Internet access properly configured and the instance must get a public IP.

Go to the __Add Storage__ section and set the size of the root device (/dev/sda1) to 40 GB.  Add a new EBS volume (/dev/sdb) of 1000 GB, select the option __Delete on Termination__ for both volumes.

Go to __Add Tags__ section -> __Add Tag__ -> Key=__Name__; Value=__baremetal-ipi__.  This is an optional step, but helps in identifying the instance when more instance exist.

Go to __Configure Security Group__.  Optionally for security reasons set the source for the SSH connections to __My IP__.  Add a new rule for the VNC service: __Add Rule__ -> Type=__Custom TCP__; Protocol=__TCP__; Port Range=__5900-5910__; Source=__My IP__; Description=__VNC__.  Add rules for __HTTP__ and __HTTPS__, these can be selected from the Type drop down.  Add a rule for the __API endpoint__, TCP port 6443.

Go to __Review and Launch__ -> __Launch__

Select an existing key pair or create a new one.  If a new one is created, download the key pair file and change its permissions:
```
$ chmod 0400 baremetalipi.pem
```
Tick the acknowledgement message " __Launch Instances__"

The metal instance will take a few minutes to start and get ready.  When the instance is up and running, connect via ssh using the key file and the instance public IP address.  This public IP will change when the host is rebooted.
```
$ ssh -i baremetalipi.pem ec2-user@35.178.191.131
```

Subscribe the host to Red Hat
```
$ sudo subscription-manager register –username <username>
```

Install the virtualization host group to support KVM virtual machines:
```
$ sudo dnf group install virtualization-host-environment
```

Install these additional packages:
```
$ sudo dnf install virt-install  libguestfs-tools tmux
```

Update the rest of the packages
```
$ sudo dnf update
```

Shutdown the instance.  In the AWS web site, go to __EC2__ -> __Instances__ -> Select the newly created instance -> __Instance State__ -> __Stop Instance__

When the instance shows a state of __Stopped__, go to __Instance State__ -> __Start instance__

When the instance is in state Running and has passed all Status checks.  Get its public IP and ssh into it
```
$ ssh -i baremetalipi.pem ec2-user@18.170.69.216
```

Optional. Start a tmux session:
```
$ tmux
```

Get the name of the device associated with the 1TB disk
```
$ sudo lsblk|grep 1000G
```
Partition the 1TB disk.  Create a single partition covering the whole disk:
```
$ sudo cfdisk /dev/nvme1n1 
```

Format the partition:
```
$ sudo mkfs.xfs /dev/nvme1n1p1
```

Mount the partition in /var/lib/libvirt/images

* Get the partition ID
```
$ sudo blkid
```
* Add an entry like the following to the /etc/fstab file
```
UUID=95534019-3…e04d98199 /var/lib/libvirt/images  xfs         defaults            0 0
```
* Restrict the permissions of the directory
```
$ sudo chmod 0751 /var/lib/libvirt/images/
```
* Apply the SeLinux file tags to the directory
```
$ sudo restorecon -R -Fv /var/lib/libvirt/images/ 
```
Create an storage pool for KVM VMs:
```
$  sudo virsh pool-define-as default dir --target /var/lib/libvirt/images/
$  sudo virsh pool-build default
$  sudo virsh pool-start default
$  sudo virsh pool-autostart default
$  sudo virsh pool-list --all --details
```
   
Start and enable the libvirtd service
```
$ sudo systemctl start libvirtd
$ sudo systemctl enable libvirtd
```

Copy the rhel8 qcow2 image: 
```
# scp -i benaka.pem rhel-8.5-x86_64-kvm.qcow2 ec2-user@44.198.53.71:
```

Create the virtual networks: routable and provisioning using the xml definitions at the top of the doc


### Import the VM providing DHCP and DNS services

* Extract the xml definition from the existing VM
```
# virsh dumpxml dhns > dhns2.xml
```

* Copy the qcow2 image file and the xml definition files to the destination host
```
# scp -i benaka.pem /var/lib/libvirt/images/dhns.qcow2 dhns.xml ec2-user@44.198.53.71:
```

* Import the VM in the destination host
```
$ sudo mv dhns.qcow2 /var/lib/libvirt/images
$ sudo ls -l /var/lib/libvirt/images
$ sudo chown qemu: /var/lib/libvirt/images/dhns.qcow2
$ sudo restorecon -R -Fv /var/lib/libvirt/images/
$ sudo virsh define dhns.xml
$ sudo virsh start dhns
```

## Redfish based architecture

In this architecture there is no provisioning network, only a routable network is required.  

The redfish protocol is provided by sushy tools.

The following links contain additional information about sushy-tools:

[https://docs.openstack.org/sushy-tools/latest/](https://docs.openstack.org/sushy-tools/latest/)
[https://gist.github.com/williamcaban/e5d02b3b7a93b497459c94446105872c](https://gist.github.com/williamcaban/e5d02b3b7a93b497459c94446105872c)

The instructions in this document set up the cluster to use legacy boot mode instead of UEFI boot mode.  UEFI boot mode can be used in the manual instructions, terraform libvirt module does not properly support UEFI.  If UEFI is required refer to section [Set up UEFI boot mode](#set-up-uefi-boot-mode)

### Prepare the physical host

A physical host with libvirt/KVM virtual machines will be used in this demonstration.

Prepare the physical host as described in section [Setup the physical host in AWS](#setup-the-physical-host-in-aws)

The default virtual network in libvirt can be used, but in this case a specific network is created for the OCP cluster.  Follow the instructions in section [Create the routable baremetal and provisioning networks in KVM](#create-the-routable-baremetal-and-provisioning-networks-in-kvm), but only create the routable (chucky) network.

### Install sushy-tools

In the physical host Install the following packages:
```
# dnf install libvirt-devel gcc python3-virtualenv httpd-tools
```

Create a python virtual environment 
```
# virtualenv-3 sushy-tools
# . sushy-tools/bin/activate
```

Install sushy tools
```
# pip3 install sushy-tools libvirt-python
```

### Setup sushy-tools

Create an SSL certificate to encrypt redfish communications (sushy tools).  Data entered to describe the certificate is not relevan in most cases:
```
$ openssl req -newkey rsa:2048 -x509 -sha256 -days 3650 \
-nodes -out sushy.cert -keyout sushy.key
Generating a RSA private key
..........................................+++++
.+++++
writing new private key to 'sushy.key'
-----
You are about to be asked to enter information that will be incorporated
into your certificate request.
What you are about to enter is what is called a Distinguished Name or a DN.
There are quite a few fields but you can leave some blank
For some fields there will be a default value,
If you enter '.', the field will be left blank.
-----
Country Name (2 letter code) [XX]:es
State or Province Name (full name) []:
Locality Name (eg, city) [Default City]:
Organization Name (eg, company) [Default Company Ltd]:
Organizational Unit Name (eg, section) []:
Common Name (eg, your name or your server's hostname) []:sushy-tools
Email Address []:
```

Review certificate:
```
$ openssl x509 -in sushy.cert -text -noout|less
```

Create a user file with a single user for basic HTTP authentication, that will be used by susy-tools.  Queries to the sushy-tools service will need to authenticate with this user.
```
$ htpasswd -c -B -b htusers admin password
```

Create the configuration file for the sushy-tools service. A reference file is provided in this repository at __redfish/sushy.conf__.  Use the correct values for the SSL certificate path, the http basic users file, etc.

If UEFI boot mode is used, the file specified in the section SUSHY_EMULATOR_BOOT_LOADER_MAP must be present in the system.  This file belongs to the package edk2-ovmf.


### Start and test sushy tools

Start the service with a command like the following.  The path to the configuration file must be absolute, not relative:
```
(sushy-tools)$ sushy-tools/bin/sushy-emulator --config /home/ec2-user/OCP4baremetalIPI/sushy.conf
 * Serving Flask app 'sushy_tools.emulator.main' (lazy loading)
 * Environment: production
   WARNING: This is a development server. Do not use it in a production deployment.
   Use a production WSGI server instead.
 * Debug mode: off
 * Running on all addresses.
   WARNING: This is a development server. Do not use it in a production deployment.
 * Running on https://172.31.75.189:8080/ (Press CTRL+C to quit)
```

In another terminal test the service with curl, the URL is obtained from the output above:
```
$ curl -k --user admin:password  https://172.31.75.189:8080/redfish/v1/Systems/                                                                             
{
"@odata.type": "#ComputerSystemCollection.ComputerSystemCollection",
"Name": "Computer System Collection",
"embers@odata.count": 1,
"embers": [
                {
                    "@odata.id": "/redfish/v1/Systems/44e3c29b-325e-4ad3-9859-c29233204a8a"
                }
],
        "@odata.context": "/redfish/v1/$metadata#ComputerSystemCollection.ComputerSystemCollection",                                                                                         
        "@odata.id": "/redfish/v1/Systems",
        "@Redfish.Copyright": "Copyright 2014-2016 Distributed anagement Task Force, Inc. (DTF). For the full DTF copyright policy, see http://www.dmtf.org/about/policies/copyright."
```

### Add firewall rules to allow access to sushy-tools

In order for the bootstrap VM to be able to control the cluster VMs via redfish protocol a firewall rule allowing access to the port where the susy-tools server is listening needs to be added to the physical host: 
```
$ sudo firewall-cmd --add-port 8080/tcp --zone=libvirt --permanent
$ sudo firewall-cmd --reload
$ sudo firewall-cmd --list-all --zone libvirt
```

### Setup DNS service

A DNS server is required to resolve the names of the hosts in the cluster and some additional service names.  Follow the instructions in the section [Creating the support VM](#creating-the-support-vm).

Alternatively the support VM can be imported following the instructions in section [Import the VM providing DHCP and DNS services](#import-the-vm-providing-dhcp-and-dns-services).

The DHCP service is optional but recommended, it is used to provide network configuration for the provisioning VM and the nodes in the OCP cluster.

### Create the provisioning VM for redfish

Create the provisioning VM following the instructions in section [Create the provisioning VM](#create-the-provisioning-vm), replace the virt-install command with the following one, which is slightly different; apply the other creation steps unchanged: 

* The reference to the provision network is removed since no such network exists
* Make sure the MAC address is unique and is the one used by the DHCP server for this VM.
```
$ sudo virt-install --name=provision --vcpus=4 --ram=24096 \
  --disk path=/var/lib/libvirt/images/provision.qcow2,bus=virtio,size=120  \
  --os-variant rhel8.5 --cpu host-passthrough,cache.mode=passthrough  \
  --network network=chucky,model=virtio,mac=52:54:00:9d:41:3c \
  --boot hd,menu=on --graphics vnc,listen=0.0.0.0 --noreboot \
  --noautoconsole --console pty,target_type=virtio
```

### Create the empty cluster hosts

Additional details can be found in the sushy-tools documentation [site](https://docs.openstack.org/sushy-tools/latest/user/dynamic-emulator.html)

Follow the instructions in sections [Create the 3 empty master nodes](#create-the-3-empty-master-nodes) and [Create two empty worker nodes](#create-two-empty-worker-nodes).
The virt-install commands are slightly different from the ones in the sections above because they don't link the hosts to the provision network, which is not used in this case:
```
# for x in {1..3}; do echo $x; virt-install --name bmipi-master${x} --vcpus=4  \ 
--ram=16384 --disk path=/var/lib/libvirt/images/bmipi-master${x}.qcow2,bus=virtio,size=40 \
--os-variant rhel8.5 --network network=chucky,model=virtio,mac=52:54:00:a9:6d:7${x} \
--boot hd,menu=on --graphics vnc,listen=0.0.0.0 --noreboot  --noautoconsole; done


# for x in {1..2}; do echo $x; virt-install --name bmipi-worker${x} --vcpus=4 \
 --ram=16384 --disk path=/var/lib/libvirt/images/bmipi-worker${x}.qcow2,bus=virtio,size=40  \
 --os-variant rhel8.5 --network network=chucky,model=virtio,mac=52:54:00:a9:6d:9${x} \        
 --boot hd,menu=on --graphics vnc,listen=0.0.0.0 --noreboot --noautoconsole; done
```

Check that the VMs are detected by susy-tools.  Use the URL reported when sushy-tools is started:
```
$ curl -k --user admin:password https://172.31.75.189:8080/redfish/v1/Systems/
{
        "@odata.type": "#ComputerSystemCollection.ComputerSystemCollection",
        "Name": "Computer System Collection",
        "embers@odata.count": 7,
        "embers": [
            
                {
                    "@odata.id": "/redfish/v1/Systems/a95336a0-7213-4df4-a0cd-1796aba76ecb"
                },
            
                {
                    "@odata.id": "/redfish/v1/Systems/36a19373-be1c-448c-8b4e-91ef597cb8e3"
                },
            
                {
                    "@odata.id": "/redfish/v1/Systems/335fe8b6-7ae4-4bf8-a492-8e11873be01b"
                },
            
                {
                    "@odata.id": "/redfish/v1/Systems/44e3c29b-325e-4ad3-9859-c29233204a8a"
                },
            
                {
                    "@odata.id": "/redfish/v1/Systems/11adbf9b-6f09-4502-bd5d-3d4d4e4a4895"
                },
            
                {
                    "@odata.id": "/redfish/v1/Systems/245184e0-9e76-42a7-b8c1-f8f64164bc82"
                },
            
                {
                    "@odata.id": "/redfish/v1/Systems/639e3f63-72d8-4a48-9052-3c1175a7a4ea"
                }
…
```

The character string in every __@odata.id__ entry is the UUID of the libvirt VM, and should match the output from the following command:
```
$ sudo virsh list --all --name --uuid
44e3c29b-325e-4ad3-9859-c29233204a8a dhns                              
335fe8b6-7ae4-4bf8-a492-8e11873be01b provision                         
245184e0-9e76-42a7-b8c1-f8f64164bc82 bmipi-master1                     
a95336a0-7213-4df4-a0cd-1796aba76ecb bmipi-master2                     
36a19373-be1c-448c-8b4e-91ef597cb8e3 bmipi-master3                     
11adbf9b-6f09-4502-bd5d-3d4d4e4a4895 bmipi-worker1                     
639e3f63-72d8-4a48-9052-3c1175a7a4ea bmipi-worker2
```

### Prepare the provision VM

Follow the instructions in sections:
* [Set up virtualization in the provisioning VM](#set-up-virtualization-in-the-provisioning-vm)
* [Preparing the provisioning node for OpenShift Container Platform installation](#preparing-the-provisioning-node-for-openshift-container-platform-installation)
* [Configure networking in the provisioning VM](#configure-networking-in-the-provisioning-vm). Apply only the parts referring to the baremetal network.
* [Get the pull secret, Openshift installer and oc client](#get-the-pull-secret-openshift-installer-and-oc-client)
 
### Create the install configuration yaml file

Use the install-config.yaml file provided in this repository at **redfish/install-config.yaml** as a reference, keep in mind that cluster name, DNS domain, IPs, ports, MACs, etc. must match the configurations options defined in other parts of this document, and changing them in this file without updating those other configurations will break the deployment process.

The VM’s UUID and its MAC address is required for each VM, use the following command to get that information.  Run this command in the physical host:

```
$ for x in bmipi-master1 bmipi-master2 bmipi-master3 bmipi-worker1 bmipi-worker2; do echo -n "${x} "; sudo virsh domuuid $x|tr "\n" " "; \
  sudo virsh domiflist $x| awk '/52:54/ {print $NF}'; done
bmipi-master1: 245184e0-9e76-42a7-b8c1-f8f64164bc82  52:54:00:a9:6d:71
bmipi-master2: a95336a0-7213-4df4-a0cd-1796aba76ecb  52:54:00:a9:6d:72
bmipi-master3: 36a19373-be1c-448c-8b4e-91ef597cb8e3  52:54:00:a9:6d:73
bmipi-worker1: 11adbf9b-6f09-4502-bd5d-3d4d4e4a4895  52:54:00:a9:6d:91
bmipi-worker2: 639e3f63-72d8-4a48-9052-3c1175a7a4ea  52:54:00:a9:6d:92
```
Adding the section rootDeviceHints is required, unlike when doing the installation using a provisioning network.

Use the IP address reported by the susy-tools server when it was started, in the __address:__ URI 
```
...
 * Running on https://172.31.69.209:8080/ (Press CTRL+C to quit) 
```

Update the hosts section and use the appropriate values for UUID and MAC for each node, for example for bmipi-master1:
```
        bmc:
          address: redfish-virtualmedia://172.31.69.209:8080/redfish/v1/Systems/245184e0-9e76-42a7-b8c1-f8f64164bc82  
          disableCertificateVerification: True
          username: admin
          password: password
        bootMACAddress: 52:54:00:a9:6d:71
        rootDeviceHints:
            deviceName: /dev/vda
```


Add the pull secret and the ssh key at the end of the file.

### Install the Openshift cluster with redfish

Create a directory and copy the install-config.yaml file into it.  This is done to make sure a copy of the install-cofig.yaml file survives the installation. The surviving copy is the one kept in the main directory:
```
$ mkdir ocp4
$ cp install-config.yaml ocp4/
```

If a previous failed install happened, remove old bootstrap resources if any are left over from a previous deployment attempt
```
$ ./openshift-baremetal-install destroy cluster --dir ocp4


$ sudo virsh list
 Id   Name                       State
--------------------------------------
 1        ocp4-876p7-bootstrap   running


$ sudo virsh destroy ocp4-876p7-bootstrap
Domain ocp4-876p7-bootstrap destroyed


$ sudo virsh undefine ocp4-876p7-bootstrap --remove-all-storage
error: Storage pool 'ocp4-876p7-bootstrap' for volume 'vda' not found.
Domain ocp4-876p7-bootstrap has been undefined
```
The error about missing volume vda is normal, nothing to worry about.


Run the installation from the provisioning host:
```
$ ./openshift-baremetal-install --dir ocp4/ create cluster
```
### Set up UEFI boot mode

Due to limitations in terraform libvirt module, the VMs created with it don't properly support UEFI, so the instructions in this project, both manual and automatic, create non UEFI capable hosts.  This should not be considered much of a limitation given that the clusters deployed using this project are not production ready or specially secure.

Still it is possible and simple to modify the instructions to use UEFI secure boot in the manual instructions:

* When [creating the empty masters and workers](#create-the-empty-cluster-hosts) add the option `--boot uefi` to the command, like in the following example:
```
# for x in {1..3}; do echo $x; virt-install --name bmipi-master${x} --vcpus=4  \ 
--ram=16384 --disk path=/var/lib/libvirt/images/bmipi-master${x}.qcow2,bus=virtio,size=40 \
--os-variant rhel8.5 --network network=chucky,model=virtio,mac=52:54:00:a9:6d:7${x} \
--boot hd,menu=on --boot uefi --graphics vnc,listen=0.0.0.0 --noreboot  --noautoconsole; done
```
```
# for x in {1..2}; do echo $x; virt-install --name bmipi-worker${x} --vcpus=4 \
 --ram=16384 --disk path=/var/lib/libvirt/images/bmipi-worker${x}.qcow2,bus=virtio,size=40  \
 --os-variant rhel8.5 --network network=chucky,model=virtio,mac=52:54:00:a9:6d:9${x} \        
 --boot hd,menu=on --boot uefi --graphics vnc,listen=0.0.0.0 --noreboot --noautoconsole; done
```
* In the file install-config.yaml remove all occurrences of the following line:
```
bootMode: legacy
```
There is one such line for every host defined in the install-config.yaml file, all must be removed so the default value of **UEFI** is used.  Alternatively the UEFI value can be specified but this is not really necessary since that is the default value. 
```
bootMode: UEFI
```
### Automatic deployment of infrastructure with ansible and terraform

It is possile to create the necessary infrastructure components using [terraform](https://www.terraform.io/downloads.html) templates and [ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html) playbooks, this simplifies and speeds up the installation process, and makes it less error prone.

For these instructions to run successfully terraform and ansible must be installed and working in the controlling host.

* Go to the [Terraform directory](Terraform/README.md) and follow the instructions to deploy the metal instance and associated components in AWS.

* Go to the [Ansible directory](Ansible/README.md) and follow the instructions in the sections: [Subscribe hosts with Red Hat](Ansible/README.md#subscribe-hosts-with-red-hat), [Add the common ssh key](Ansible#add-the-common-ssh-key) and [Running the playbook to configure the metal EC2 instance](Ansible#running-the-playbook-to-configure-the-metal-ec2-instance)

* Optionally get more insights about the libvirt resources, run [virt manager](https://virt-manager.org/) on the localhost as explained in [Connecting to the VMs with virt-manager](#connecting-to-the-VMs-with-virt-manager).  The configuration tasks have been executed by the ansible playbook so only the connection command needs to be run.

* Go to the [Terraform/libvirt directory](Terraform/libvirt/README.md) and follow the instructions to create the libvirt/KVM resources.  Make sure to define the variable `architecture = "redfish"`

* Go back to the [Ansible directory](Ansible/README.md) and follow the instructions in sections [Set up KVM instances](Ansible#set-up-kvm-instances) and [Running the playbook for libvirt VMs](Ansible#running-the-playbook-for-libvirt-vms)

* SSh into the provisioning node as the kni user. Make sure to [add the ssh key to the shell](Ansible#add-the-common-ssh-key). The connection can be stablish [using the EC2 instance as a jump host](Ansible#running-tasks-in-via-a-jumphost-with-ssh)

     The home directory of the kni user contains all necessary files to run the Openshift installation, and all the require infrastructure should be in place and ready.
```
$ ssh -J ec2-user@3.219.143.250  kni@192.168.30.10
```

* Review the install-config.yaml file and add or modify the configuratin options.

* Copy the install-config.yaml file into the directory with the name of the cluster

* Run the [Openshift installer](#install-the-openshift-cluster-with-bmc)

### Destroying the infrastructure in redfish based architecture

The instructions to destroy the cluster and the accompanying infrastructure are the same used in the [provisioning network design](#destroying-the-infrastructure-in-provisioning-network-design).

## External access to Openshift using NGINX

The Openshift cluster resulting from applying the instructions in this document is only accessible from the metal EC2 and the provisioning VM hosts.  The reason is, despite being a public cluster, the IPs for the API endpoint and ingress controller are assigned from the routable virtual network which is not accessible from outside the metal EC2 host.

The solution used here to access the cluster from outside the physical host is to deploy a reverse proxy in the physical host and use it to rely requests to the Openshift cluster.  A reverse proxy based on NGINX is used.

The reverse proxy contains different configuration sections for accessing the API endpoint, secure application routes on port 443 and insecure application routes on port 80.

The external DNS names used to access the applications and API endpoint can be different from the internal ones used by Openshift.  If the Openshift cluster was deployed using an internal DNS zone that is not resolvable from outside the physical host, the reverse proxy can do the translation between the external and internal zones.
```
                  ┌────────┐                        ┌────────┐
                  │        │                        │        │
          ────────► NGINX  ├───────────────────────►│ OCP 4  │
app1.example.com  │        │  app1.ocp4.company.dom │        │
                  └────────┘                        └────────┘
```

The one caveat about DNS zones translation is that the web console (https://console-openshift-console.apps.ocp4.tale.net) and the OAuth server (https://oauth-openshift.apps.ocp4.tale.net) can only be accessed using a single URL and DNS zone, so zone translation in the reverse proxy does not work for these two services.  

The console and oauth URLs can be changed from their default values, but can only be accessed using the configured URL, and the new DNS names must be resolvable from inside the cluster: [Customizing the console route](https://docs.openshift.com/container-platform/4.9/web_console/customizing-the-web-console.html#customizing-the-console-route_customizing-web-console) and [Customizing the OAuth server URL](https://docs.openshift.com/container-platform/4.9/authentication/configuring-internal-oauth.html#customizing-the-oauth-server-url_configuring-internal-oauth)  

DNS entries for the API and APPS endpoints, resolving to the public IP of the physical host need to be created.  A public DNS resolver, a [local DNS server based on dnsmasq](#configuring-dns-resolution-with-dnsmasq) or adding the entries to the locahost file could be used to resolve the console and oauth internal DNS names.

The reverse proxy also supports the websocket protocol used in the web console to show some of the cluster information like the container logs.

Additional details about the NGINX configuration can be found in the [nginx directory](nginx/)

Manual an automatic instructions on how to install and set up NGINX are provided in the following sections.

### Install and set up NGINX
The following commands must be run in the physical host.

Install NGINX packages
```
$ sudo dnf install nginx
```

Enable and start NGINX service
```
$ sudo systemctl enable nginx --now
$ sudo systemctl status nginx
```
Create DNS entries in the public DNS zone for the API endpoint (__api.ocp4.redhat.com__) and the default ingress controller (__\*.apps.ocp4.redhat.com__) resolving to the public IP of the host where ngnix is listening.  Do this in the public DNS resolver hosting the zone, for example route 53 in AWS, or using dnsmasq in your localhost.  

```
$ host api.ocp4.redhat.com
api.ocp4.redhat.com has address 34.219.150.17

$ host *.apps.ocp4.redhat.com 
*.apps.ocp4.redhat.com has address 34.219.150.17
```

Create a file in NGINX defining the reverse proxy configuration to access the Openshift cluster and place it in **/etc/nginx/conf.d/**.  An example file is provided in this repository at nginx/ocp4.conf:

Copy the file to /etc/nginx/conf.d/
```
$ sudo cp ocp4.conf /etc/nginx/conf.d/
```
The NGINX configuration file contains the definition for a virtual server to access secure application routes, this virtual server definition requires an SSL certificate to encrypt connections between the client and the NGINX server.  This certificate should be valid for the DNS domain served by the virtual server, in the example __apps.ocp4.redhat.com__, however the certificate used in this example is obtained from the Openshift cluster default ingress controller which is valid for __apps.ocp4.tale.net__: 

Extracted the cerfiticate from the OCP 4 cluster, the following command will create two files:
```
$ oc extract secret/router-certs-default -n openshift-ingress
tls.crt
tls.key
```
Copy the certificate files to the path specified in the NGINX virtual server configuration:
```
  ssl_certificate "/etc/pki/nginx/ocp-apps.crt";
  ssl_certificate_key "/etc/pki/nginx/private/ocp-apps.key";
```
Create the directories if they don't exist, and copy the files
```
$ sudo mkdir /etc/pki/nginx/
$ sudo cp tls.crt /etc/pki/nginx/ocp-apps.crt
$ sudo mkdir /etc/pki/nginx/private/
$ sudo cp tls.key /etc/pki/nginx/private/ocp-apps.key
$ sudo ls -l /etc/pki/nginx/
```
A similar procedure is used to collect the API endpoint x509 certificate, the __--confirm__ option is used to overwrite any existing file with the same name.
```
$ oc extract secret/external-loadbalancer-serving-certkey -n openshift-kube-apiserver --confirm
```
Copy the certificate files to the path specified in the NGINX virtual server configuration:
```
  ssl_certificate "/etc/pki/nginx/ocp-api.crt";
  ssl_certificate_key "/etc/pki/nginx/private/ocp-api.key";

$ sudo cp tls.crt /etc/pki/nginx/ocp-api.crt
$ sudo cp tls.key /etc/pki/nginx/private/ocp-api.key
$ sudo ls -l /etc/pki/nginx/
```
Restore the SELinux file labels:
```
$ sudo restorecon -R -Fv /etc/pki/nginx
Relabeled /etc/pki/nginx from unconfined_u:object_r:cert_t:s0 to system_u:object_r:cert_t:s0
Relabeled /etc/pki/nginx/ocp-apps.crt from unconfined_u:object_r:cert_t:s0 to system_u:object_r:cert_t:s0
Relabeled /etc/pki/nginx/private from unconfined_u:object_r:cert_t:s0 to system_u:object_r:cert_t:s0
Relabeled /etc/pki/nginx/private/ocp-apps.key from unconfined_u:object_r:cert_t:s0 to system_u:object_r:cert_t:s0
Relabeled /etc/pki/nginx/private/ocp-api.key from unconfined_u:object_r:cert_t:s0 to system_u:object_r:cert_t:s0
Relabeled /etc/pki/nginx/ocp-api.crt from unconfined_u:object_r:cert_t:s0 to system_u:object_r:cert_t:s0
```

Review the configuration file and update the IP associated with the **proxy_pass** directives, use the IP for the internal default ingress controller and the API endpoint.  
```
provision $ dig +short \*.apps.ocp4.tale.net
192.168.30.110
provision $ dig + short \api.ocp4.tale.net
192.168.30.100

...
    proxy_pass https://192.168.30.110;
...
    proxy_pass https://192.168.30.100;
```

Use the correct external and internal DNS domains in every virtual server definition:
```
...
  server_name \*.apps.ocp4.redhat.com;
...
    proxy_set_header Host $host_head.apps.ocp4.tale.net;
...
    proxy_ssl_name $host_head.apps.ocp4.tale.net;
...
  server_name api.ocp4.redhat.com;
```
Update the local DNS resolution for the following records to resolve with the public IP where the nginx reverse proxy is providing service. For example:
```
*.apps.ocp4.tale.net   44.200.45.58
api.ocp4.tale.net      44.200.45.58
```
Verify that the configuration is correct:
```
$ sudo nginx -t
```

Reload the nginx configuration
```
$ sudo systemctl reload nginx
$ sudo systemctl status nginx
```

Enable http and https access through the firewall in the physical host
```
$ sudo firewall-cmd --add-service https --add-service http --zone public --permanent
```
The API endopint listens on port 6443 so this port needs to be enable in the firewall
```
$ sudo firewall-cmd --add-port 6443/tcp --zone public --permanent
```
Finally reload the firewall configuration and verify that the configuration has been correctly applied

```
$ sudo firewall-cmd --reload
$ sudo firewall-cmd --list-all --zone public
```
In case of using an AWS EC2 instance, add the ports 443 and 6443 to the security group in the AWS EC2 instance.

If the physical host uses SELinux, it is possible that the nginx service is not allowed to open outgoing network connections, a message like the following will appear in the physical host's audit log
```
type=AVC msg=audit(1646133037.928:6189): avc:  denied  { name_connect } for  pid=420527 comm="nginx" dest=443 scontext=system_u:system_r:httpd_t:s 0 tcontext=system_u:object_r:http_port_t:s0 tclass=tcp_socket permissive=0
```
In that case the following SELinux boolean needs to be enable to allow nginx user to stablish outbound network connections. The **-P** option is used to make the change persistent across reboots:
```
$ sudo setsebool -P httpd_can_network_connect on

$ sudo getsebool httpd_can_network_connect
httpd_can_network_connect --> on
```
SELinux will also block NGINX from listening on the API endpoint port 6443. To allow access to this port use the following command
```
$ sudo semanage port -a -t http_port_t -p tcp 6443
$ sudo semanage port -l|grep 6443
http_port_t                    tcp      6443, 80, 81, 443, 488, 8008, 8009, 8443, 9000
```
Reload NGINX configuration to apply the changes
```
$ sudo systemctl reload nginx
```
### Install and set up NGINX with Ansible

The installation and configuration of NGINX can be done using an ansible playbook, check the instructions in section [Install and set up NGINX with Ansible](Ansible/README.md#install-and-set-up-nginx-with-ansible)

### Configuring DNS resolution with dnsmasq
Here is how to set up dnsmasq in the client host to resolve the DNS queries for the API and application routes in the Openshift cluster.  

In this example dnsmasq is running as a NetworkManager plugging as is the case in Fedora and RHEL servers, if it was running as a standalone service the files are in /etc/dnsmasq.conf and /etc/dnsmasq.d/

To define dnsmasq as the default DNS server add a file to __/etc/NetworkManager/conf.d/__, any filename ending in .conf is good, with the contents:
```
[main]
dns=dnsmasq
```
Create a file in __/etc/NetworkManager/dnsmasq.d/__, again any filename ending in .conf is good.  This file contains the resolution records for the domain in question, the following example file contains two records:
* A type A record that resolves a single hostname into the IP address of the Application Gateway
* A wildcard type A record that resolves a whole DNS domain into the IP address of the Application Gateway
```
host-record=api.jupiter.example.com,20.97.425.13
address=/.apps.jupiter.example.com/20.97.425.13
```
Now restart the NetworkManager service with:
```
$ sudo systemctl restart NetworkManager
```
The file /etc/resolv.conf should now contain a line pointing to 127.0.0.1 as the name server:
```
$ $ cat /etc/resolv.conf
# Generated by NetworkManager
...
nameserver 127.0.0.1
```
The resolution should be working now:
```
$ dig +short api.jupiter.example.com
20.97.425.13
```

### Accessing the cluster
Accessing the cluster is done in the same way as for any other cluster, except that the DNS domain used is the external dns zone defined in NGINX virtual servers:

* Using the __oc__ client

    To login using the __oc__ client use the external name defined in the virtual server and the 6443 port.  In the following example the certificate used in NGINX is extracted from the cluster, hence the warning message.
```
$ oc login -u kubeadmin -p fI...geI https://api.ocp4.redhat.com:6443
The server is using a certificate that does not match its hostname: x509: certificate is valid for api.ocp4.tale.net, not api.redhat.com
You can bypass the certificate check, but any data you send to the server could be intercepted by others.
Use insecure connections? (y/n): y

Login successful.

You have access to 67 projects, the list has been suppressed. You can list all projects with 'oc projects'

Using project "default".
```
* Access to application routes

    For secure and non secure routes, the URL must contain the external DNS domain defined in the NGINX virtual servers.  In the following example the external domain is **redhat.com**:
```
$ curl http://httpd-example-bandido.redhat.com/
```
* Access to the web console and oauth service

    For the special case of the web console and oauth service, the URL must use the internal DNS domain (https://console-openshift-console.apps.ocp4.tale.net and  https://oauth-openshift.apps.ocp4.tale.net).  This can be achieved by adding this names to the hosts file in the local host.

## Enable Internal Image Registry
In a berametal IPI Openshift cluster, the internal image registry is not available after installation, this can be verified by checking the value of managementState in the registry configuration, if the value is __Removed__ the registry is not available:

```
$ oc get configs.imageregistry/cluster -o yaml
...
spec:
  logLevel: Normal
  managementState: Removed
...
```
The reason for this is that no storage for the image registry has been configured.  Follow the instruction in the official documentation [Configuring the registry for bare metal ](https://docs.openshift.com/container-platform/4.9/registry/configuring_registry_storage/configuring-registry-storage-baremetal.html) to setup the image registry.

When the image registry operator is set to managed and a valid storage is added, some cluster operators will get updated, check their status to make sure they progress as expected
```
watch oc get co
```

In non production and test environments it is possible to use emptyDir as a storage option to have a working registry quicly, however this option is not persistent, if the registry pod is restarted all images stored in the registry are lost. 
```
provision $ oc edit configs.imageregistry/cluster
spec:
  managementState: Managed
  ...
  storage:
    emptyDir: {}
```

In the following example the storage will be provided by additional volumes added to the worker KVM VMs

### Add Storage to the Worker Nodes
An additional storage volume is created for each of the worker nodes.  The following commands are run in the physical host.
```
 # for x in {1..2}; do virsh vol-create-as default worker${x}-vol2.qcow2 5G --format qcow2; done
 # virsh vol-list --pool default
```

Attach the volumes created above to the worker VMs:
```
# for x in {1..2}; do virsh attach-disk bmipi-worker${x} /var/lib/libvirt/images/worker${x}-vol2.qcow2 vdb --driver qemu --subdriver qcow2 --live --config; done
Disk attached successfully

Disk attached successfully
```

Verify that the disks are correctly attached as the vdb device:
```
# for x in {1..2}; do echo WORKER${x}; virsh dumpxml bmipi-worker${x}|grep -A4 '<disk'; done
WORKER1
    <disk type='file' device='disk'>
      <driver name='qemu' type='qcow2'/>
      <source file='/var/lib/libvirt/images/BMIPI-worker1.qcow2' index='1'/>
      <backingStore/>
      <target dev='vda' bus='virtio'/>
--
    <disk type='file' device='disk'>
      <driver name='qemu' type='qcow2'/>
      <source file='/var/lib/libvirt/images/worker1-vol2.qcow2' index='2'/>
      <backingStore/>
      <target dev='vdb' bus='virtio'/>
WORKER2
    <disk type='file' device='disk'>
      <driver name='qemu' type='qcow2'/>
      <source file='/var/lib/libvirt/images/BMIPI-worker2.qcow2' index='1'/>
      <backingStore/>
      <target dev='vda' bus='virtio'/>
--
    <disk type='file' device='disk'>
      <driver name='qemu' type='qcow2'/>
      <source file='/var/lib/libvirt/images/worker2-vol2.qcow2' index='2'/>
      <backingStore/>
      <target dev='vdb' bus='virtio'/>

provision $ ssh -i .ssh/bmipi core@192.168.30.30 lsblk
NAME   MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
vda    252:0    0   40G  0 disk 
├─vda1 252:1    0    1M  0 part 
├─vda2 252:2    0  127M  0 part 
├─vda3 252:3    0  384M  0 part /boot
├─vda4 252:4    0 39.4G  0 part /sysroot
└─vda5 252:5    0   65M  0 part 
vdb    252:16   0    5G  0 disk 

 # ssh -i .ssh/bmipi core@192.168.30.31 lsblk
NAME   MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
vda    252:0    0   40G  0 disk 
├─vda1 252:1    0    1M  0 part 
├─vda2 252:2    0  127M  0 part 
├─vda3 252:3    0  384M  0 part /boot
├─vda4 252:4    0 39.4G  0 part /sysroot
└─vda5 252:5    0   65M  0 part 
vdb    252:16   0    5G  0 disk
```
The new disks will be added as PVs using the [Local Storage Operator](https://docs.openshift.com/container-platform/4.9/storage/persistent_storage/persistent-storage-local.html) follow the instructions in the [official documentation](https://docs.openshift.com/container-platform/4.9/storage/persistent_storage/persistent-storage-local.html) to install and setup the Operator.

An example definition for the local volume can be found in the file **storage/localVolume-vol2.yaml**
```
provision $ oc create -f local-volume.yaml 
localvolume.local.storage.openshift.io/vol2 created
```

Verify that the local volume and PVs were created
```
provision $ oc get localvolume -n openshift-local-storage
NAME   AGE
vol2   4m59s

provision $ oc get pv
NAME                CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS      CLAIM   STORAGECLASS   REASON   AGE
local-pv-10328d04   5Gi        RWO            Delete           Available           registorage             5m31s
local-pv-9fa5f293   5Gi        RWO            Delete           Available           registorage             5m34s
```
### Make the internal image registry operational

Once there are Persistent Volumes (PVs) available to be used by the internal image registry, assign one of them to the registry.

The official documentation instructions will not work in this particular case because of the storage used here: RWO vs RWX, and non default storage class.  [Configuring the registry for bare metal](https://docs.openshift.com/container-platform/4.9/registry/configuring_registry_storage/configuring-registry-storage-baremetal.html)

The steps to make the registry operational are:

* Change the management state to __Managed__
* Change the rolloutStrategy to Recreate
* Add a storage claim

All these configuration changes are applied to the object __configs.imageregistry/cluster__.

The storage provided by the Local Storage operator is of type ReadWriteOnce (RWO) which limits the image registry deployment to one pod instance, making the servie not highly available.

Create a PVC that will bind to one of the PVs provided by the local storage operator, this PVC will later be assigned to the registry.  A file definition example can be found in at **storage/image-registry-storage-PVC.yaml**.  Make sure that the size specified in the PVC, the access mode and the storage class name all match those of the PV:
```
provision $ oc get pv
NAME                CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS      CLAIM     STORAGECLASS   REASON   AGE
local-pv-9fa5f293   5Gi        RWO            Delete           Available             registorage             16h

provision $ grep -A7 spec image-registry-storage-PVC.yaml
spec:
  storageClassName: "registorage"
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  volumeMode: Filesystem
```
Create the PVC 
```
provision $ oc create -f image-registry-storage-PVC.yaml
```
Initially the PVC is not bound to the PV, it is waiting for the claim to be used by a pod.

Assign the storage to the image registry and set the management status to managed.  Set the rolloutStrategy to Recreate, this may be required if the type of storage used is RWO, if the rolloutStrategy is kept as RollingUpdate the following message may appear in the status section of the config object `Unable to apply resources: unable to sync storage configuration: cannot use ReadWriteOnce access mode with RollingUpdate rollout strategy`

Edit the configuration object and add the following code.  Make sure that the name of the claim matches the name of the PVC created earlier:
```
provision $ oc edit configs.imageregistry/cluster
spec:
  managementState: Managed
  rolloutStrategy: Recreate
  storage:
    pvc:
      claim: image-registry-storage
...
```
Verify that the PVC has bound to a PV
provision $ oc get pvc
NAME                     STATUS   VOLUME              CAPACITY   ACCESS MODES   STORAGECLASS   AGE
image-registry-storage   Bound    local-pv-10328d04   5Gi        RWO            registorage    15h

Verify that a new image-registry pod is created in the namespace openshift-image-registry
```
$ oc get pods -n openshift-image-registry
NAME                                               READY   STATUS    RESTARTS      AGE
cluster-image-registry-operator-859997cd74-4cpc6   1/1     Running   9 (46m ago)   21d
image-registry-547586978b-2s9vb                    1/1     Running   1             16h
...
```
The internal image registry is ready for use.

## Using a bonding interface as the main NIC

To install the cluster using a bonding interface as the main NIC in all nodes (master and workers), each node needs 2 ethernet NICS connected to the routable network.  If the installation is usng a provisioning network, an additional NIC connected to the provisioning network is required.  The terraform libvirt.tf template takes care of the creation of all the NICs.  

There are two options to create the bonding interface in the nodes: Use terraform and ansible to create the bonding interface (preferred); or create the bonding interface after the cluster has been installed, this last option does not really work as of 4.10.

### Obtaining the NIC names

To find out the names that RHELCOS will assign to the devices associated with the network interfaces follow this steps, do this before running the openshift installer.

* Find out the URL for the RHELCOS iso image for your hardware architecture.  This step uses the openshift installer binary so it must be run from the provisioning host after the support_setup ansible playbook has been run.
```
./openshift-baremetal-install coreos print-stream-json|grep location|grep iso|grep x86_64
"location": "https://rhcos-redirector.apps.art.xq1c.p1.openshiftapps.com/art/storage/releases/rhcos-4.10/410.84.202201251210-0/x86_64/rhcos-410.84.202201251210-0-live.x86_64.iso",
```
* Download the iso image obtained in the previous step.  Run this command in the metal instance.
```
wget https://rhcos-redirector.apps.art.xq1c.p1.openshiftapps.com/art/storage/releases/rhcos-4.10/410.84.202201251210-0/x86_64/rhcos-410.84.202201251210-0-live.x86_64.iso
```
* Copy the iso image to the directory representing the default libvirt storage pool
```
sudo cp rhcos-410.84.202201251210-0-live.x86_64.iso /var/lib/libvirt/images/
```
* Add a CDROM device to one of the VMs.  All VMs have the same network configuration so only one of them will be inspected.  Virt Manager can be used to, click the lightbulb icon (Show virtual hardware details) --> Add Hardware -> Storage -> Device type: CDROM device -> Select or create custom storage -> Manage -> select the iso image file from the list -> Finish

* Enable the boot menu.  This allows selecting the CDROM as a boot device while not changing the default device boot order.  Again use the virt manager for convenience.  Click the lightbulb icon (Show virtual hardware details) --> Boot Options -> Enable boot menu -> Apply

* Boot up the VM using the CDROM as boot device.  Again use the virt manager for convenience.

     Click the monitor icon (Show the graphical console) -> Push the Play button (Power on the Virtual Machine) -> Click on the terminal area and press Escape to show the boot menu.

     If the menu does not show up, leave the termina by pressing CTRL + ALT, click the "Shut down the VM" button and select Force reset.

     When the boot menu appears, select DVD/CD option by pressing the number to the left of that option in the keyboard.

* When RHELCOS boots up, it returns a shell prompt.  Run any of the following commands to find the network interface names
```
nmcli con show

ip link
```

* Shutdown the VM.  Again use the virt manager for convenience.  Click the "Shut down the VM" button and select Force reset.

* (Optional) Remove the CDROM device from the VM.  Virt Manager can be used to, click the lightbulb icon (Show virtual hardware details) --> Select the CDROM device -> Remove


### Create the bonding interface during cluster installation

The libvirt terraform template and the support_setup ansible playbook in this repository create the neccesary infrastructure and configuration files to deploy the cluster with a bonding interface.

This creation process mainly depends on two variables: **bonding_nic** and **ocp_minor_version**.  If **bonding_nic=true** terraform adds an additional NIC connected to the routable network to form the bonding device, and ansible adds the networkConfig section to the install-config.yaml file with the configuration of the bonding device, but still **ocp_minor_version** needs to be 10 or above for the additional NIC and the bonding configuration to be created, this is because OCP 4.10 is the first version in which the installation supports a bonding NIC.
```
ocp_version = "4.10.22"
bonding_nic = true
```

The ansible playbook **support_setup.yaml**, in particular the template install-config.j2 for vbmc and redfish, takes care of creating a correct networkConfig section for all nodes if the aforementioned variables have been correctly defined.
```
{% if bonding_nic and (ocp_version | regex_search('4\\.([0-9]+)\\.','\\1')| list | first | int  >= 10) %}
        networkConfig:
          interfaces:
          - name: bond0
            type: bond
            state: up
            ipv4:
              dhcp: true
              enabled: true
            ipv6:
              enabled: false
            link-aggregation:
              mode: active-backup
              options:
                miimon: '140'
              port:
              - ens4
              - ens3
{% else %}
#Version 4.{{ ocp_version | regex_search('4\\.([0-9]+)\\.','\\1')| list | first | int }} not compatible with bonding interface for installation
{% endif %}
```

There is no need to apply the instructions in article [Preventing DHCP from assigning an IP address on node reboot](https://access.redhat.com/articles/6865841).

### Node certificates manual approval

**This bug has been fixed in latest versions of 4.11.z and in 4.12**

During the installation, the kubelet certificate requests for the worker nodes are not automatically approved by the machine approver operator and must be approved manually.  This is a bug and should not happen.  

The logs in the machine approver operator show the following messages.  The messages exist for all worker nodes and repeat until the csrs are manually approved.  The last messages coincide with the manual approval of the certificate requests:
```
oc logs machine-approver-8945758f5-6nllp -c machine-approver-controller -n openshift-cluster-machine-approver
...
I0621 10:09:12.966921       1 controller.go:120] Reconciling CSR: csr-9rxtp
I0621 10:09:12.986320       1 csr_check.go:157] csr-9rxtp: CSR does not appear to be client csr
I0621 10:09:12.989674       1 csr_check.go:545] retrieving serving cert from worker0.zianuro.poin.care (192.168.55.30:10250)
I0621 10:09:12.990940       1 csr_check.go:182] Failed to retrieve current serving cert: remote error: tls: internal error
I0621 10:09:12.991002       1 csr_check.go:202] Falling back to machine-api authorization for worker0.zianuro.poin.care
E0621 10:09:12.991027       1 csr_check.go:360] csr-9rxtp: Serving Cert: No target machine for node "worker0.zianuro.poin.care"
I0621 10:09:12.991050       1 csr_check.go:205] Could not use Machine for serving cert authorization: Unable to find machine for node
I0621 10:09:12.995235       1 controller.go:228] csr-9rxtp: CSR not authorized
I0621 10:10:07.244963       1 controller.go:120] Reconciling CSR: csr-bpcjd
I0621 10:10:07.261427       1 csr_check.go:157] csr-bpcjd: CSR does not appear to be client csr
I0621 10:10:07.263773       1 csr_check.go:545] retrieving serving cert from worker2.zianuro.poin.care (192.168.55.32:10250)
I0621 10:10:07.264678       1 csr_check.go:182] Failed to retrieve current serving cert: remote error: tls: internal error
I0621 10:10:07.264727       1 csr_check.go:202] Falling back to machine-api authorization for worker2.zianuro.poin.care
E0621 10:10:07.264748       1 csr_check.go:360] csr-bpcjd: Serving Cert: No target machine for node "worker2.zianuro.poin.care"
I0621 10:10:07.264767       1 csr_check.go:205] Could not use Machine for serving cert authorization: Unable to find machine for node
I0621 10:10:07.267156       1 controller.go:228] csr-bpcjd: CSR not authorized
I0621 10:11:48.853525       1 controller.go:120] Reconciling CSR: csr-7cr8r
I0621 10:11:48.875137       1 controller.go:209] csr-7cr8r: CSR is already approved
I0621 10:11:48.904754       1 controller.go:120] Reconciling CSR: csr-7cr8r
I0621 10:11:48.926305       1 controller.go:209] csr-7cr8r: CSR is already approved
I0621 10:11:48.936748       1 controller.go:120] Reconciling CSR: csr-9rxtp
I0621 10:11:48.958246       1 controller.go:209] csr-9rxtp: CSR is already approved
...
```
This [KCS article](https://access.redhat.com/solutions/6561351) helps understand the problem with node certificates.

Wait for the message `INFO Destroying the bootstrap resources...`, in another session in the provisioning node, log into the cluster:
```
export KUBECONFIG=zianuro/auth/kubeconfig
```
Get a list of pending certificate signing requests.
```
oc get csr|grep -i pending
csr-9rxtp          4m30s   kubernetes.io/kubelet-serving         system:node:worker0.zianuro.poin.care                                         <none>              Pending
csr-bpcjd          3m36s   kubernetes.io/kubelet-serving         system:node:worker2.zianuro.poin.care                                             <none>              Pending
```
When the output contains a csr for each of the worker nodes, approve them with the command:
```
for x in $(oc get csr|grep -i pending|awk '{print $1}'); do oc adm certificate approve $x; done
```
The kubelet certificates created during installation have a short expiration date of around 24 hours.  Can be checked with the following command:
```
for x in $(oc get nodes --no-headers|awk '{print $1}'); do echo $x;oc debug node/${x} -- chroot /host cat /var/lib/kubelet/pki/kubelet-client-current.pem | openssl x509 -dates -noout; done
master0.zianuro.poin.care
Starting pod/master0zianuropoincare-debug ...
To use host binaries, run `chroot /host`
notBefore=Jun 22 07:49:46 2022 GMT
notAfter=Jun 23 07:31:30 2022 GMT
...
```
This certificates are automatically renewed between 30% and 10% of their valid time remaining, but will require manual approval again, and on every subsequent renewals.

Even if the worker nodes kubelet certificate requests are not approved, the installation will succeed, but several issues will happen during cluster normal operation, like not being able to connect to a node or pod with the following commands:
```
oc rsh <podname>

oc debug node/<nodename>
```
Another issue is that the image prunner job fails because the pod running the job, can't connect to the registry service:
```
oc get pod image-pruner-27590994-sqlvc -o yaml

containerStatuses:
...
      message: |
        error: failed to ping registry https://image-registry.openshift-image-registry.svc:5000: Get "https://image-registry.openshift-image-registry.svc:5000/": dial tcp 172.30.53.141:5000: i/o timeout
```

And many other issues in which the kubelet takes an active role:

### Create the bonding interface after cluster installation

This method doesn't really work as expected, the cluster is installed but the bonding interface was not successfully created, see note at the end of the section.

To create the bonding interface after cluster installation, start with two NICS coneected to the same routable network (chucky), in this example they are called ens4 and ens5.  The name of the NICS is assigned by RHELCOS, to find out what names will be used, see section [Obtaining the NIC names](#obtaining-the-nic-names)

We only want to use one NIC to deploy the cluster.  The trick is to disable the second interface during installation.

To disable the NIC ens5 use the following networkConfig section for the nodes in the install-config.yaml file.  The ens4 NIC is enabled and gets an IP from the DHCP server.  The ens5 NIC is  activated but does not get any IP, neither v4 or v6.  
```
networkConfig:
  interfaces:
  - name: ens4
    type: ethernet
    state: up
    ipv4:
      dhcp: true
      enabled: true
  - name: ens5
    type: ethernet
    state: up
    ipv4:
      enabled: false
    ipv6:
      enabled: false
```
If the state of the ens5 NIC is __absent__ or __down__ the Network Manager in RHELCOS brings it up and sets it to get an IP via DHCP, this causes trouble because the routing table prioritizes the first interface (ens4) but the in the routing table because two NICS are connected to the same netowrk, and the OCP installation does not complete successfully.

Besides the above, the instructions in article [Preventing DHCP from assigning an IP address on node reboot](https://access.redhat.com/articles/6865841) must be applied.  The files Ansible/vbmc/cluster-network-03-nic-master.yml and Ansible/vbmc/cluster-network-03-nic-worker.yml can be used to disable DHCP for ens5 in all masters and workers.

When the installation is completed we end up with a painted into the corner situation.  We have a working cluster with an active ens4 NIC, and a disabled ens5.  However attempting to create a bond using ens4 and ens5 is likely to disconnect the node(s) from the network, effectively moving them out of reach and impossible to recover.  The following information notice may give an explanation: https://docs.openshift.com/container-platform/4.10/networking/k8s_nmstate/k8s-nmstate-observing-node-network-state.html#virt-about-nmstate_k8s-nmstate-observing-node-network-state 


### Test the bonding interface

When the installation is completed open a shell with one of the nodes
```
oc debug node/worker3.zianuro.poin.care
Starting pod/worker3zianuropoincare-debug ...
To use host binaries, run `chroot /host`
cPod IP: 192.168.55.33
If you don't see a command prompt, try pressing enter.
sh-4.4# chroot /host
sh-4.4#
```
Check the network interfaces.

In this example the interfaces ens3 and ens4 are slaves of bond0.  All 3 have the same MAC address which originally comes from ens3
```
ip link
2: ens3: <BROADCAST,MULTICAST,SLAVE,UP,LOWER_UP> mtu 1500 qdisc fq_codel master bond0 state UP mode DEFAULT group default qlen 1000
    link/ether 52:54:00:a9:6d:93 brd ff:ff:ff:ff:ff:ff
3: ens4: <BROADCAST,MULTICAST,SLAVE,UP,LOWER_UP> mtu 1500 qdisc fq_codel master bond0 state UP mode DEFAULT group default qlen 1000
    link/ether 52:54:00:a9:6d:93 brd ff:ff:ff:ff:ff:ff permaddr 52:54:00:5b:6d:93
4: bond0: <BROADCAST,MULTICAST,MASTER,UP,LOWER_UP> mtu 1500 qdisc noqueue master ovs-system state UP mode DEFAULT group default qlen 1000
    link/ether 52:54:00:a9:6d:93 brd ff:ff:ff:ff:ff:ff
```
Check the status of the bond0 interface.  Here we see that the type of bonding is active backup and the active interface is ens4.  Both interfaces are up.
```
sh-4.4# cat /proc/net/bonding/bond0
Ethernet Channel Bonding Driver: v4.18.0-305.45.1.el8_4.x86_64

Bonding Mode: fault-tolerance (active-backup)
Primary Slave: None
Currently Active Slave: ens4
MII Status: up
MII Polling Interval (ms): 140
Up Delay (ms): 0
Down Delay (ms): 0
Peer Notification Delay (ms): 0

Slave Interface: ens3
MII Status: up
Speed: Unknown
Duplex: Unknown
Link Failure Count: 1
Permanent HW addr: 52:54:00:a9:6d:93
Slave queue ID: 0

Slave Interface: ens4
MII Status: up
Speed: Unknown
Duplex: Unknown
Link Failure Count: 1
Permanent HW addr: 52:54:00:5b:6d:93
Slave queue ID: 0
```
Get the names and MACs of the network interfaces.  In this example they are vnet134 and vnet135
```
virsh -c qemu:///system dumpxml bmipi-worker3 |grep -A 5 "interface type='network'"
    <interface type='network'>
      <mac address='52:54:00:a9:6d:93'/>
      <source network='chucky' portid='bc096a9d-ccff-479b-af6e-3bd30c427e20' bridge='chucky'/>
      <target dev='vnet134'/>
      <model type='virtio'/>
      <link state='up'/>
--
    <interface type='network'>
      <mac address='52:54:00:5b:6d:93'/>
      <source network='chucky' portid='a10f82b3-e3a6-43ed-9712-9f0d64867c35' bridge='chucky'/>
      <target dev='vnet135'/>
      <model type='virtio'/>
      <link state='up'/>
```
Simulate the unplugging of ens4.  Run the following command from the hypervisor (metal instance).

Let's assume that ens4 is vnet135 and shut it down with the following command in the hypervisor
```
virsh -c qemu:///system domif-setlink bmipi-worker3 vnet135 down
Device updated successfully
```
Check the interface link in the hypervisor
```
virsh -c qemu:///system domif-getlink bmipi-worker3 vnet135
vnet135 down
```
Check the link inside the VM.  ens4 has NO-CARRIER and is in state DOWN, however the bond interface is still working.
```
ip link
2: ens3: <BROADCAST,MULTICAST,SLAVE,UP,LOWER_UP> mtu 1500 qdisc fq_codel master bond0 state UP mode DEFAULT group default qlen 1000
    link/ether 52:54:00:a9:6d:93 brd ff:ff:ff:ff:ff:ff
3: ens4: <NO-CARRIER,BROADCAST,MULTICAST,SLAVE,UP> mtu 1500 qdisc fq_codel master bond0 state DOWN mode DEFAULT group default qlen 1000
    link/ether 52:54:00:a9:6d:93 brd ff:ff:ff:ff:ff:ff permaddr 52:54:00:5b:6d:93
4: bond0: <BROADCAST,MULTICAST,MASTER,UP,LOWER_UP> mtu 1500 qdisc noqueue master ovs-system state UP mode DEFAULT group default qlen 1000
    link/ether 52:54:00:a9:6d:93 brd ff:ff:ff:ff:ff:ff
```
Further details can be obtained from the bond interface.  The active slave has changed to ens3 but the MAC address is still the same as before.
```
cat /proc/net/bonding/bond0
Ethernet Channel Bonding Driver: v4.18.0-305.45.1.el8_4.x86_64

Bonding Mode: fault-tolerance (active-backup)
Primary Slave: None
Currently Active Slave: ens3
MII Status: up
MII Polling Interval (ms): 140
Up Delay (ms): 0
Down Delay (ms): 0
Peer Notification Delay (ms): 0

Slave Interface: ens3
MII Status: up
Speed: Unknown
Duplex: Unknown
Link Failure Count: 1
Permanent HW addr: 52:54:00:a9:6d:93
Slave queue ID: 0

Slave Interface: ens4
MII Status: down
Speed: Unknown
Duplex: Unknown
Link Failure Count: 2
Permanent HW addr: 52:54:00:5b:6d:93
Slave queue ID: 0
```
Bring the ens4 interface back up
```
virsh -c qemu:///system domif-setlink bmipi-worker3 vnet135 up
Device updated successfully
```
Check the status of the bond interface.  The ens4 interface is now up but the main slave has not changed.  During the whole tests there has not been any appreciable disruption to the communications with the node.
```
cat /proc/net/bonding/bond0
Ethernet Channel Bonding Driver: v4.18.0-305.45.1.el8_4.x86_64

Bonding Mode: fault-tolerance (active-backup)
Primary Slave: None
Currently Active Slave: ens3
MII Status: up
MII Polling Interval (ms): 140
Up Delay (ms): 0
Down Delay (ms): 0
Peer Notification Delay (ms): 0

Slave Interface: ens3
MII Status: up
Speed: Unknown
Duplex: Unknown
Link Failure Count: 1
Permanent HW addr: 52:54:00:a9:6d:93
Slave queue ID: 0

Slave Interface: ens4
MII Status: up
Speed: Unknown
Duplex: Unknown
Link Failure Count: 2
Permanent HW addr: 52:54:00:5b:6d:93
Slave queue ID: 0
```
