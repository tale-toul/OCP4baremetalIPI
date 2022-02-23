# Baremetal IPI Openshift 4 on libvirt KVM

## Table of contents

* [Reference documentation](#reference-documentation)
* [Provisioning Network Based Architecture Design](#provisioning-network-based-architecture-design)
* [Create the routable baremetal and provisioning networks in KVM](#create-the-routable-baremetal-and-provisioning-networks-in-kvm)
* [Create the provisioning VM](#create-the-provisioning-vm) 
* [Create the 3 empty master nodes](#create-the-3-empty-master-nodes)
* [Create two empty worker nodes](#create-two-empty-worker-nodes)
* [Install and set up vBMC in the physical node](#install-and-set-up-vbmc-in-the-physical-node) 
Add firewall rules to allow the VMs to access the vbmcd service        9
Set up virtualization in the provisioning VM        9
Verify DNS resolution in the provisioning VM        10
Preparing the provisioning node for OpenShift Container Platform installation        10
Configure networking in the provisioning VM        11
Get the pull secret, Openshift installer and oc client        13
Create the install-config.yaml file        13
Install the Openshift cluster        15
Troubleshooting the installation        16
Connecting to the VMs with virt-manager        17
Creating the support VM        18
Setup the physical host in AWS        23
Import the VM providing DHCP and DNS services.        25
Redfish based architecture        26
Prepare the physical host        26
Install sushy-tools        26
Setup sushy-tools        27
Start and test sushy tools        29
Add firewall rules to allow access to sushy-tools        29
Setup DNS service        29
Create the provisioning VM        30
Create the empty cluster hosts        30
Prepare the provision VM        31
Create the install-config.yaml file        31
Install the Openshift cluster        33


## Reference documentation

The official documentation explains in detail how to install an Openshift 4 cluster using the baremetal IPI method:
[Deploying installer-provisioned clusters on bare metal Overview](https://docs.openshift.com/container-platform/4.9/installing/installing_bare_metal_ipi/ipi-install-overview.html)

## Provisioning Network Based Architecture Design

The architecture design for this cluster is as follows:
* Uses KVM based virtual machines.
* Uses both a bare metal network and a provisioning network.

![Provisioning network base architecture](images/arch1.png)
  
The physical server (AKA hypervisor) where the KVM VMs are created must support nested virtualization and have it enabled: [Using nested virtualization in KVM](https://docs.fedoraproject.org/en-US/quick-docs/using-nested-virtualization-in-kvm/)

Check if nested virtualization is supported, a value of 1 means that it is supported and enabled.
```
# cat /sys/module/kvm_intel/parameters/nested
1
```

Enable nested virtualization if it is not, this is a one time configuration [Enabling nested virtualization in KVM](https://docs.fedoraproject.org/en-US/quick-docs/using-nested-virtualization-in-kvm/#_enabling_nested_virtualization): 

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

## Create the routable baremetal and provisioning networks in KVM

The definition for the routable baremetal network can be found in the file _net-chucky.xml_.  It is a simple definition of a routable network with no DHCP using the network address space 192.168.30.0/24
The definition for the provisioning network can be found in the file net-provision.xml.  The file contains the definition of a non routable network with no DHCP using the network address space 192.168.14.0/24

Create the networks with the commands:
```
# virsh net-define chucky.xml
# virsh net-define provision.xml
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

## Create the provisioning VM

Get the qcow2 image for RHEL 8 from access.redhat.com -> Downloads -> Red Hat Enterprise Linux 8 -> Red Hat Enterprise Linux 8.5 KVM Guest Image

Copy the qcow2 image file to the libvirt images directory 
```
# cp rhel-8.5-x86_64-kvm.qcow2 /var/lib/libvirt/images/provision.qcow2
# chown qemu: /var/lib/libvirt/images/provision.qcow2
```

Restore the SELinux file tags:
```
$ sudo restorecon -R -Fv /var/lib/libvirt/images/provision.qcow2
```

Create the VM instance based on the above image with the following commands.  The MAC address is specified in the command line to make it predictable and easier to match to later configuration files:
```
# export VM_NAME=provision
# export DST_AMI_PATH="/var/lib/libvirt/images"
# export DST_AMI_IMAGE=$DST_AMI_PATH/$VM_NAME.qcow2

# virt-customize -a $DST_AMI_IMAGE --root-password password:mypassword \
   --uninstall cloud-init

# virt-install --name=${VM_NAME} --vcpus=4 --ram=24096 \
            --disk path=${DST_AMI_IMAGE},bus=virtio,size=120 \
            --os-variant rhel8.5 --network network=provision \
           --cpu host-passthrough,cache.mode=passthrough \
            --network network=chucky,model=virtio,mac=52:54:00:9d:41:3c \
            --boot hd,menu=on --graphics vnc,listen=0.0.0.0 --noreboot \
            --noautoconsole --console pty,target_type=virtio
```

Resize the VM disk, do this before starting the VM:
```
# qemu-img resize ${DST_AMI_IMAGE} 120G
```

Complete the resizing from inside the VM
```
# virsh start $VM_NAME
```

Connect to the provision VM.  There are two alternatives:
* From the virtual console (To leave console mode use CTRL+] )
```
# virsh console $VM_NAME
```
* From an ssh connection
```
$ sudo virsh domifaddr provision --source arp
 Name           MAC address              Protocol         Address
-------------------------------------------------------------------------------
 vnet2          52:54:00:9d:41:3c        ipv4             192.168.30.10/0

$ ssh root@192.168.30.10

[root@localhost ~]# growpart /dev/vda 3
…
[root@localhost ~]# xfs_growfs /dev/vda3
…
[root@localhost ~]# df -Ph
```

## Create the 3 empty master nodes

These don’t include an OS

First create the empty disks
```
# for x in master{1..3}; do echo $x; \
   qemu-img create -f qcow2 /var/lib/libvirt/images/BMIPI-${x}.qcow2 80G; \
   done
```

Update the SELinux file tags
```
# restorecon -R -Fv /var/lib/libvirt/images/BMIPI-master*
```

Change the owner and group to qemu:
```
# for x in master{1..3}; do echo $x; chown qemu: \
    /var/lib/libvirt/images/BMIPI-${x}.qcow2; done
```

Create the 3 master VMs using the empty disks created in the previous step.  These are connected to both the routable and the provisioning networks.  The order in which the NICS are created is important so that if the VM cannot boot from the disk, which is the case at first boot, it will try to do it through the NIC in the provisioning network first, where the DHCP and PXE services from ironiq will provide the necessary information. 

The MAC addresses for the routable and provisioning network NICs are specified so they can easily match the ones added to the external DHCP and install-config.yaml file, without the need to update the configuration of those services every time a new set of machines are created:

```
# for x in {1..3}; do echo $x; virt-install --name bmipi-master${x} --vcpus=4 \
   --ram=16384 --disk \
   path=/var/lib/libvirt/images/BMIPI-master${x}.qcow2,bus=virtio,size=80 \
   --os-variant rhel8.5 --network network=provision,mac=52:54:00:74:dc:a${x} \
   --network network=chucky,model=virtio,mac=52:54:00:a9:6d:7${x} \
   --boot hd,menu=on --graphics vnc,listen=0.0.0.0 --noreboot \
   --noautoconsole; done
```

## Create two empty worker nodes

These don’t include an OS

First create the empty disks:
```
# for x in worker{1..2}; do echo $x; \
   qemu-img create -f qcow2 /var/lib/libvirt/images/BMIPI-${x}.qcow2 80G; done
```

Update the SELinux file tags
```
# restorecon -R -Fv /var/lib/libvirt/images/BMIPI-worker*
```
Change the owner and group to qemu:
```
# for x in worker{1..2}; do echo $x; chown qemu: \
   /var/lib/libvirt/images/BMIPI-${x}.qcow2; done
```


Create the 2 worker nodes using the empty disks created in the previous step.  These are connected to both the routable and the provisioning networks.  The order in which the NICS are created is important so that if the VM cannot boot from the disk, which is the case at first boot, it will try to do it through the NIC in the provisioning network first, where the DHCP and PXE services from ironiq will provide the necessary information. 

The MAC addresses for the routable and provisioning network NICs are specified so they can easily match the ones added to the external DHCP and install-config.yaml file, without the need to update the configuration of those services every time a new set of machines are created:
```
# for x in {1..2}; do echo $x; virt-install --name bmipi-worker${x} --vcpus=4 \
   --ram=16384 --disk \
   path=/var/lib/libvirt/images/BMIPI-worker${x}.qcow2,bus=virtio,size=80 \
   --os-variant rhel8.5 --network network=provision,mac=52:54:00:74:dc:d${x} \
   --network network=chucky,model=virtio,mac=52:54:00:a9:6d:9${x} \
   --boot hd,menu=on --graphics vnc,listen=0.0.0.0 --noreboot \
   --noautoconsole; done
```

Check that all VMs are created:
```
# virsh list –all
```

## Install and set up vBMC in the physical node


Install the following packages in the physical server


# dnf install gcc libvirt-devel python3-virtualenv ipmitool


Create a python virtual environment to install vBMC


# virtualenv-3 virtualbmc


# . virtualbmc/bin/activate


Install virtual BMC in the python virtual environment:


(virtualbmc) # pip install virtualbmc


Start the vbmcd daemon in the python virtual environment:


(virtualbmc) # ./virtualbmc/bin/vbmcd


Find the IP address of the bridge connected to the routable network (chucky) in the physical machine:


# virsh net-dumpxml chucky
…
  <bridge name='virbr2' stp='on' delay='0'/>
  <mac address='52:54:00:6a:56:bc'/>
  <ip address='192.168.30.1' netmask='255.255.255.0'>
  </ip>
</network>
 
Can also be checked with:


# ip -4 a show dev virbr2
5: virbr2: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
        inet 192.168.30.1/24 brd 192.168.30.255 scope global virbr2


Add the master and worker node VMs to virtual BMC, use the IP obtained before to contact the vbmcd daemon and a unique port for each VM, the ports are arbitrary but should be above 1024.  The name of the node is the one shown in the output of virsh list –all command:


(virtualbmc) # for x in {1..3}; do vbmc add --username admin --password secreto \
                          --port 700${x} --address 192.168.30.1 bmipi-master${x}; done


(virtualbmc) # for x in {1..2}; do vbmc add --username admin --password secreto \
                          --port 701${x} --address 192.168.30.1 bmipi-worker${x}; done


Check that the VMs are accepted:


(virtualbmc) # vbmc list
+---------------+--------+--------------+------+
| Domain name   | Status | Address          | Port |
+---------------+--------+--------------+------+
| bmipi-master1 | down   | 192.168.30.1 | 7001 |
| bmipi-master2 | down   | 192.168.30.1 | 7002 |
| bmipi-master3 | down   | 192.168.30.1 | 7003 |
| bmipi-worker1 | down   | 192.168.30.1 | 7011 |
| bmipi-worker2 | down   | 192.168.30.1 | 7012 |
+---------------+--------+--------------+------+


Start a virtual BMC service for every virtual machine instance:


(virtualbmc) # for x in {1..3}; do vbmc start bmipi-master${x}; done


(virtualbmc) # for x in {1..2}; do vbmc start bmipi-worker${x}; done


The status in the vbmc list command changes to running.  This is not the VM running but the BMC service for that VM


(virtualbmc) # vbmc list
+---------------+---------+--------------+------+
| Domain name   | Status  | Address          | Port |
+---------------+---------+--------------+------+
| bmipi-master1 | running | 192.168.30.1 | 7001 |
| bmipi-master2 | running | 192.168.30.1 | 7002 |
| bmipi-master3 | running | 192.168.30.1 | 7003 |
| bmipi-worker1 | running | 192.168.30.1 | 7011 |
| bmipi-worker2 | running | 192.168.30.1 | 7012 |
+---------------+---------+--------------+------+


Verify Power status of Vm's


(virtualbmc) # for x in {1..3}; do ipmitool -I lanplus -U admin -P secreto \
                    -H 192.168.30.1 -p 700${x} power status; done
Chassis Power is off
Chassis Power is off
Chassis Power is off


(virtualbmc) # for x in {1..2}; do ipmitool -I lanplus -U admin -P secreto \
                          -H 192.168.30.1 -p 701${x} power status; done
Chassis Power is off
Chassis Power is off


Add firewall rules to allow the VMs to access the vbmcd service
These rules are created in the physical host:


# firewall-cmd –add-port 7001/udp –add-port 7002/udp –add-port 7003/udp \
   –add-port 7011/udp –add-port 7012/udp --zone=libvirt --permanent
# firewall-cmd --reload
# firewall-cmd --list-all --zone libvirt
Set up virtualization in the provisioning VM 
Set up nested virtualization in the provisioning VM
https://docs.fedoraproject.org/en-US/quick-docs/using-nested-virtualization-in-kvm/#proc_configuring-nested-virtualization-in-virt-manager


The support VM with DHCP and DNS services must be already set up and running.


If it is not already started, start the provision VM
# virsh start provision 


Connect from the physical host to the provision VM using the IP defined in the DHCP server for that host
$ ssh root@192.168.30.10


Register the provision VM with Red Hat
# subscription-manager register --user <rh user>


Install the host virtualization software:
# dnf group install virtualization-host-environment


Update the Operating System
# dnf update
# reboot


Verify that the provisioning VM has virtualization correctly set up, last 2 warnings are not relevant they also come up when running the same command in the physical host:


provision # virt-host-validate
  QEMU: Checking for hardware virtualization                                     : PASS
  QEMU: Checking if device /dev/kvm exists                                       : PASS
  QEMU: Checking if device /dev/kvm is accessible                                : PASS
  QEMU: Checking if device /dev/vhost-net exists                                 : PASS
  QEMU: Checking if device /dev/net/tun exists                                   : PASS
  QEMU: Checking for cgroup 'cpu' controller support                             : PASS
  QEMU: Checking for cgroup 'cpuacct' controller support                         : PASS
  QEMU: Checking for cgroup 'cpuset' controller support                          : PASS
  QEMU: Checking for cgroup 'memory' controller support                  : PASS
  QEMU: Checking for cgroup 'devices' controller support                         : PASS
  QEMU: Checking for cgroup 'blkio' controller support                           : PASS
  QEMU: Checking for device assignment IOMMU support                             : WARN (No ACPI DMAR table found, IOMMU either disabled in BIOS or not supported by this hardware platform)
  QEMU: Checking for secure guest support                                        : WARN (Unknown if this platform has Secure Guest support)


Verify DNS resolution in the provisioning VM
[root@provision ~]# for x in {1..3}; do dig master${x}.ocp4.tale.net +short; done
192.168.30.20
192.168.30.21
192.168.30.22
[root@provision ~]# for x in {1..2}; do dig worker${x}.ocp4.tale.net +short; done
192.168.30.30
192.168.30.31


Preparing the provisioning node for OpenShift Container Platform installation
https://docs.openshift.com/container-platform/4.9/installing/installing_bare_metal_ipi/ipi-install-installation-workflow.html#preparing-the-provisioner-node-for-openshift-install_ipi-install-installation-workflow


Create a non privileged user and provide that user with sudo privileges::
# useradd kni
# passwd kni
# echo "kni ALL=(root) NOPASSWD:ALL" | tee -a /etc/sudoers.d/kni
# chmod 0440 /etc/sudoers.d/kni


Enable the http service in the firewall:
Make sure the firewalld service is enabled and running:
# systemctl enable firewalld --now
# systemctl status firewalld

Add the rules:
$ firewall-cmd --zone=public --add-service=http --permanent
$ firewall-cmd --reload

Create an ssh key for the new user:
# su - kni -c "ssh-keygen -t ed25519 -f /home/kni/.ssh/id_rsa -N ''"


Log in as the new user on the provisioner node:
# su - kni


Install the following required packages, some may already be installed:
$ sudo dnf install libvirt qemu-kvm mkisofs python3-devel jq ipmitool


Modify the user to add the libvirt group to the newly created user:
$ sudo usermod --append --groups libvirt kni


Start and enable the libvirtd service:
$ sudo systemctl enable libvirtd --now
$ sudo systemctl status libvirtd


Create the default storage pool and start it:
$ sudo virsh pool-define-as --name default --type dir --target /var/lib/libvirt/images


$ sudo virsh pool-list --all
 Name          State          Autostart
-----------------------------------------
 default           inactive   no


$ sudo virsh pool-start default
Pool default started


]$ sudo virsh pool-autostart default
Pool default marked as autostarted


$ sudo virsh pool-list --all –details
 Name          State        Autostart
--------------------------------------------
 default          active   yes


Configure networking in the provisioning VM
Do this from a local terminal or the connection will be dropped half way through the configuration.
Even if a network connection is already active and working follow the next steps:
# virsh console provision
# su - kni
$ sudo nmcli con show
NAME                                 UUID                                                                 TYPE              DEVICE
Wired connection 2  1af5c70e-3d13-3ca7-92a9-e2582e653372  ethernet  eth1   
virbr0                  b1ff2de8-0b3f-4d60-bb91-8b03078fc155               bridge            virbr0
Wired connection 1  3defbd59-64c2-3806-947a-c1be05a4752e  ethernet  --


$ ip -4 a
…
3: eth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
        inet 192.168.30.10/24 brd 192.168.30.255 scope …
4: virbr0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state DOWN group default qlen 1000
        inet 192.168.122.1/24 brd 192.168.122.255 scope global virbr0


Set up the connection to the routable network
$ sudo nmcli con down "Wired connection 2"
Connection 'Wired connection 2' successfully deactivated …


$ sudo nmcli con delete "Wired connection 2"


$ sudo nmcli con add ifname baremetal type bridge con-name baremetal
$ sudo nmcli con add type bridge-slave ifname eth1 master baremetal
Connection 'bridge-slave-eth1' … successfully added.


Now the dhcp client should assign the same IP to the new bridge interface, if not, reactivate the connection:
$ nmcli con down baremetal
$ nmcli con up baremetal


Next the provisioning network interface is reconfigured, this can be done from an ssh connection to the provisioning host since the provisioning network interface does not affect that.


$ sudo nmcli con down "Wired connection 1"
Connection 'Wired connection 1' successfully deactivated …
$ sudo nmcli con delete "Wired connection 1"
Connection 'Wired connection 1' … successfully deleted.


$ sudo nmcli con add type bridge ifname provision con-name provision
Connection 'provision' … successfully added.
$ sudo nmcli con add type bridge-slave ifname eth0 master provision
Connection 'bridge-slave-eth0' … successfully added.


Assign an IPv4 address to the provision bridge.  Use the same IP that the provision bridge is using in the physical host (this may not be really a requirement and any other IP in the provisioning network could be valid):
$ sudo nmcli con mod provision ipv4.addresses 192.168.14.1/24 \
    ipv4.method manual


Activate the provision network connection:
$ sudo nmcli con up provision


Check out the results
$ nmcli con show provision
$ ip -4 a


Get the pull secret, Openshift installer and oc client
Get a pull secret from https://console.redhat.com/openshift/install/metal/user-provisioned
And paste it into a file in the kni user home directory.
$ vim pull-secret.txt


Download the Openshift client and installer.  
$ export VERSION=stable-4.9
$ export RELEASE_IMAGE=$(curl -s https://mirror.openshift.com/pub/openshift-v4/clients/ocp/$VERSION/release.txt | grep 'Pull From: quay.io' | awk -F ' ' '{print $3}')
$ export cmd=openshift-baremetal-install
$ export pullsecret_file=~/pull-secret.txt
$ export extract_dir=$(pwd)
$ echo $extract_dir
$ curl -s https://mirror.openshift.com/pub/openshift-v4/clients/ocp/$VERSION/openshift-client-linux.tar.gz | tar zxvf - oc
$ sudo cp oc /usr/local/bin
$ oc adm release extract --registry-config "${pullsecret_file}" --command=$cmd --to "${extract_dir}" ${RELEASE_IMAGE}


Create the install-config.yaml file




apiVersion: v1
basedomain: tale.net
metadata:
  name: ocp4
networking:
  machineNetwork:
  - cidr: 192.168.30.0/24
  networkType: OVNKubernetes
compute:
- name: worker
  replicas: 2
controlPlane:
  name: master
  replicas: 3
  platform:
        baremetal: {}
platform:
  baremetal:
        apiVIP: 192.168.30.100
        ingressVIP: 192.168.30.110
        provisioningDHCPRange: 192.168.14.10,192.168.14.100
        provisioningBridge: provision
        provisioningNetworkCIDR: 192.168.14.0/24
        hosts:
        - name: bmipi-master1
            role: master
            bmc:
                address: ipmi://192.168.30.1:7001
                disableCertificateVerification: true
                username: admin
                password: secreto
            bootMACAddress: 52:54:00:74:dc:a1
            hardwareProfile: libvirt
        - name: bmipi-master2
            role: master
            bmc:
                address: ipmi://192.168.30.1:7002
                disableCertificateVerification: true
                username: admin
                password: secreto
            bootMACAddress: 52:54:00:74:dc:a2
            hardwareProfile: libvirt
        - name: bmipi-master3
            role: master
            bmc:
                address: ipmi://192.168.30.1:7003
                disableCertificateVerification: true
                username: admin
                password: secreto
            bootMACAddress: 52:54:00:74:dc:a3
            hardwareProfile: libvirt
        - name: bmipi-worker1
            role: worker
            bmc:
                address: ipmi://192.168.30.1:7011
                disableCertificateVerification: true
                username: admin
                password: secreto
            bootMACAddress: 52:54:00:74:dc:d1
            hardwareProfile: libvirt
        - name: bmipi-worker2
            role: worker
            bmc:
                address: ipmi://192.168.30.1:7012
                disableCertificateVerification: true
                username: admin
                password: secreto
            bootMACAddress: 52:54:00:74:dc:d2
            hardwareProfile: libvirt
pullSecret: …
sshKey: …


Install the Openshift cluster
Create a directory and copy the install-config.yaml file into it.  This is done to make sure a copy of the install-cofig.yaml file survives the installation. The surviving copy is the one kept in the main directory:
$ mkdir ocp4
$ cp install-config.yaml ocp4/


Ensure all bare metal nodes are powered off, the following commands are run on the physical host:


# for x in {1..3}; do ipmitool -I lanplus -U admin -P secreto \
                    -H 192.168.30.1 -p 700${x} power status; done
Chassis Power is off
Chassis Power is off
Chassis Power is off


# for x in {1..2}; do ipmitool -I lanplus -U admin -P secreto \
                          -H 192.168.30.1 -p 701${x} power status; done
Chassis Power is off
Chassis Power is off


Remove old bootstrap resources if any are left over from a previous deployment attempt


Create the OpenShift Container Platform manifests.  Run this command as the kni user from the provisioning node:
$ ./openshift-baremetal-install --dir ocp4/ create manifests
INFO Consuming Install Config from target directory
WARNING Discarding the Openshift Manifests that was provided in the target directory because its dependencies are dirty and it needs to be regenerated
INFO Manifests created in: ocp4/manifests and ocp4/openshift


Enable booting from the network device connected to the provisioning network, and make sure it is disabled for any other NIC.  This can be done from virt manager going to every master and worker, Boot Options, Boot device order, check the nic connected to the provisioning network.  But it should be possible to do it in the virt-install command.


Run the installation from the provisioning host:
$ ./openshift-baremetal-install --dir ocp4/ create cluster
Troubleshooting the installation
Check the installation log in the provisioning host as the kni user:
$ tail -f ocp4/.openshift_install.log


Check if the bootstrap VM has been created and is running in the provisioning node (nested virtualization):
[kni@provision ~]$ sudo virsh list --all
 Id        Name                            State
--------------------------------------------------------
 1        ocp4-x7578-bootstrap   running


If the bootstrap is running, ssh into it and check the logs there.
To get the bootstrap VM IP find the MAC addresses of the VM
[kni@provision ~]$ sudo virsh dumpxml ocp4-x7578-bootstrap|grep \
                                 -A 1 'mac address'
          <mac address='52:54:00:1e:71:48'/>
          <source bridge='baremetal'/>
--
          <mac address='52:54:00:46:f2:5a'/>
          <source bridge='provision'/>


Get the list of MAC to IP mappings, in the example the first entry matches the mac of the baremetal network with the IP it uses:
kni@provision ~]$ ip neigh
192.168.30.80 dev baremetal lladdr 52:54:00:1e:71:48 STALE
192.168.30.100 dev baremetal lladdr 52:54:00:1e:71:48 REACHABLE
192.168.30.1 dev baremetal lladdr 52:54:00:6a:56:bc DELAY
192.168.30.3 dev baremetal lladdr 52:54:00:19:5a:4e STALE


Connect to the bootstrap node using the core user, the ssh certificate that was used in the install-config.yaml file and the IP obtained in the previous step.  
The connection is established from the physical host:
# ssh -i .ssh/bmipi core@192.168.30.80


Check the pods running in the bootstrap VM
# sudo podman ps


Check the logs in the ironic pods
[core@localhost ~]$ sudo podman logs -f ironic-inspector
[core@localhost ~]$ sudo podman logs -f ironic-conductor
[core@localhost ~]$ sudo podman logs -f ironic-api


Run ipmitool from the ironic-conductor pod
$ sudo podman exec -ti ironic-conductor /bin/bash
[root@localhost /]# ipmitool -I lanplus -U admin -P secreto -H 192.168.30.1 \
-p 7000 power status           
Error: Unable to establish IPMI v2 / RMCP+ session
The same command from the provisioning host does not work either.
However that command does work from the physical host so it looks like this is a firewall issue.


To remove the resources created by a failed installation:
* Run the destroy cluster command:
[kni@provision ~]$ ./openshift-baremetal-install --dir ocp4/ destroy cluster                                                                                                             
INFO Deleted volume                                    volume=ocp4-x7578-bootstrap-base
INFO Deleted volume                                    volume=ocp4-x7578-bootstrap
INFO Deleted volume                                    volume=ocp4-x7578-bootstrap.ign
INFO Deleted pool                                      pool=ocp4-x7578-bootstrap
INFO Time elapsed: 0s
* Remove the bootstrap VM and its associated storage devices:
[kni@provision ~]$ sudo virsh destroy ocp4-x7578-bootstrap                                                                                                                              
Domain ocp4-x7578-bootstrap destroyed


[kni@provision ~]$ sudo virsh undefine ocp4-x7578-bootstrap \
                                   --remove-all-storage                                                                                                        
error: Storage pool 'ocp4-x7578-bootstrap' for volume 'vda' not found.
Domain ocp4-x7578-bootstrap has been undefined


The error message is because the previous destroy cluster command removed the storage pools already.


To use tcpdump inside the bootstrap machine check the following documentation section and KCS:
https://docs.openshift.com/container-platform/4.9/support/gathering-cluster-data.html#about-toolbox_gathering-cluster-data
https://access.redhat.com/articles/4365651




The provisioning network configuration can be checked with the following command:
$ oc get provisioning -o yaml


The baremetal hosts configuration can be retrieved with the following command:
$ oc -n openshift-machine-api get bmh
Connecting to the VMs with virt-manager
In AWS metal instance
Add the ec2-user to the libvirt group:
$ sudo usermod -a -G libvirt ec2-user
$ virsh -c qemu:///system list


Add firewall rules in the physical host to connect to the VNC ports. Better to use a range of ports
$ sudo firewall-cmd --list-all --zone public
$ sudo firewall-cmd --add-port 5900-5910/tcp --zone=public  --permanent
$ sudo firewall-cmd --reload
$ sudo firewall-cmd --list-all --zone public


Add the same ports above to the security rule in the AWS instance


Connecto to libvirt from the remote host with a command like:
$ virt-manager -c 'qemu+ssh://ec2-user@44.200.144.12/system?keyfile=benaka.pem'


In the “Display VNC” section of the VM hardware details in virt-manager, the field Address must contain the value “All interfaces”.  This can be set at VM creation with virt-manager.
Creating the support VM
This VM will run the DHCP and DNS services 
It will be based on the rhel 8 qcow2 image


Copy the qcow2 image file to the libvirt images directory 


# cp rhel-8.5-x86_64-kvm.qcow2 /var/lib/libvirt/images/dhns.qcow2


Create the VM instance based on the above image with the following commands:


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


Set up IP configuration.  Networking will be reconfigured during the setup of the VM, but for now is required to have the ability to install packages.


# nmcli con delete "Wired connection 1"
# nmcli con add con-name eth0 type ethernet \
    ifname eth0 autoconnect yes ip4 192.168.30.3 gw4 192.168.30.1
# nmcli con mod eth0 +ipv4.dns 192.168.100.1
# nmcli con up eth0


Subscribe the VM to Red Hat


# subscription-manager register --user <rh user>
# yum update


Assign a permanent hostname
# hostnamectl set-hostname dhns.tale.net


Set up DNS and DHCP


Install the packages
# yum install bind bind-utils dhcp-server


Start and enable named:
# systemctl enable --now named


Use the following configuration files:


/etc/named:
—--------------------------------------------------------------------------------
options {                                                                                         
            listen-on port 53 { any; };                                                               
            listen-on-v6 port 53 { any; };                                                            
            directory           "/var/named";                                                             
            dump-file           "/var/named/data/cache_dump.db";                                          
            statistics-file "/var/named/data/named_stats.txt";                                        
            memstatistics-file "/var/named/data/named_mem_stats.txt";                                 
            secroots-file   "/var/named/data/named.secroots";                                         
            recursing-file  "/var/named/data/named.recursing";                                        
            allow-query         { localhost; 192.168.30.0/24; };                                          
            allow-recursion { localhost; 192.168.30.0/24; };                                          
            allow-update { none; };                                                                   
            allow-transfer { localhost; };                                                            
                                                                                                  
            recursion yes;                                                                            
                                                                                                  
            dnssec-enable yes;                                                                        
            dnssec-validation yes;                                                                    
            managed-keys-directory "/var/named/dynamic";                                              
                                                                                                  
            pid-file "/run/named/named.pid";                                                          
            session-keyfile "/run/named/session.key";                                                 
                                                                                                  
            include "/etc/crypto-policies/back-ends/bind.config";                                     
};                                                                                                
                                                                                                  
logging {                                                                                         
            channel default_debug {                                                                   
                    file "data/named.run";                                                            
                    severity dynamic;                                                                 
            };                                                                                        
};


zone "." IN {                                                                                     
            type hint;                                                                                
            file "named.ca";                                                                          
};


include "/etc/named.rfc1912.zones";
include "/etc/named.root.key";
include "/etc/named/tale.zones";
—----------------------------------------------------------------------------------




/etc/named/tale.zones
—------------------------------------------------------------------------------------
zone "tale.net" IN {
            type master;
            file "tale.net.zone";


};


//backward zone
zone "30.168.192.in-addr.arpa" IN {
            type master;
            file "tale.net.rzone";


};
—------------------------------------------------------------------------------------


/var/named/tale.net.zone
—------------------------------------------------------------------------------------
$TTL 1D
@           IN SOA   tale.net. root.tale.net. (
                                            0           ; serial
                                            1D          ; refresh
                                            1H          ; retry
                                            1W          ; expire
                                            3H )        ; minimum
                     IN         NS          dhns.tale.net.
dhns                 IN         A           192.168.30.3
provision            IN         A           192.168.30.10


master1.ocp4              IN            A           192.168.30.20
master2.ocp4              IN            A           192.168.30.21
master3.ocp4              IN            A           192.168.30.22
worker1.ocp4              IN            A           192.168.30.30
worker2.ocp4              IN            A           192.168.30.31


api.ocp4                  IN            A           192.168.30.100
api-int.ocp4              IN            A           192.168.30.101
*.apps.ocp4               IN            A           192.168.30.110
—------------------------------------------------------------------------------------




/var/named/tale.net.rzone
—------------------------------------------------------------------------------------
$TTL        86400
@           IN          SOA         tale.net. root.example.com.  (
        202202023 ; serial
        28800          ; refresh
        14400          ; retry
        3600000        ; expire
        86400 )        ; minimum
                IN  NS          dhns.tale.net.
3               IN  PTR         dhns.tale.net.
10              IN  PTR         provision.tale.net.
20              IN  PTR         master1.ocp4.tale.net.
21              IN  PTR         master2.ocp4.tale.net.
22              IN  PTR         master3.ocp4.tale.net.
30              IN  PTR         worker1.ocp4.tale.net.
31              IN  PTR         worker2.ocp4.tale.net.


100             IN  PTR         api.ocp4.tale.net.
101             IN  PTR         api-int.ocp4.tale.net.
—------------------------------------------------------------------------------------


Change the owner of the last two files:
# chown named:named /var/named/tale.net.zone /var/named/tale.net.rzone


Reload the bind named:
# systemctl reload named


Check for errors:
# journalctl -u named -e


Verify forward and reverse resolution:


# dig @192.168.30.3 master1.ocp4.tale.net +short
# dig @192.168.30.3 -x 192.168.30.3 +short


Update the network configuration to reflect the new DNS server


# nmcli con mod eth0 +ipv4.dns 127.0.0.1 -ipv4.dns 192.168.100.1 \
   +ipv4.dns-search tale.net


Restart the network connection, this must be done on a local connection because the network will go down after the first command:
# nmcli con down eth0
# nmcli con up eth0




Configure the DHCP service


This is the configuration file used


/etc/dhcp/dhcpd.conf
—---------------------------------------------------------------------------------------------------
option domain-name "tale.net";                                                                    
default-lease-time 86400;                                                                         
max-lease-time 86400;                                                                             
log-facility local7;                                                                              
                                                                                                  
subnet 192.168.30.0 netmask 255.255.255.0 {                                                       
  range 192.168.30.80  192.168.30.100;                                                            
  option domain-name-servers 192.168.30.3;                                                        
  option domain-name "tale.net";                                                                  
  option domain-search "tale.net";                                                                
  option routers 192.168.30.1;                                                                    
  option subnet-mask 255.255.255.0;                                                               
}                                                                                                 
                                                                                                  
host provision {                                                                                  
  hardware ethernet 52:54:00:9d:41:3c;                                                            
  fixed-address 192.168.30.10;                                                                    
  option host-name "provision.tale.net";                                                          
}                                                                                                 
                                                                                                  
host master1 {                                                                                    
  hardware ethernet 52:54:00:a9:6d:71; 
  fixed-address 192.168.30.20;                                                                    
  option host-name "master1.ocp4.tale.net";                                                       
}                                                                                                 
                                                                                                  
host master2 {                                                                                    
  hardware ethernet 52:54:00:a9:6d:72;
  fixed-address 192.168.30.21;                                                                    
  option host-name "master2.ocp4.tale.net";                                                       
}


host master3 {                                                                                    
  hardware ethernet 52:54:00:a9:6d:73;                                                            
  fixed-address 192.168.30.22;                                                                    
  option host-name "master3.ocp4.tale.net";
}


host worker1 {
  hardware ethernet 52:54:00:a9:6d:91;
  fixed-address 192.168.30.30;
  option host-name "worker1.ocp4.tale.net";
}


host worker2 {
  hardware ethernet  52:54:00:a9:6d:92;
  fixed-address 192.168.30.31;
  option host-name "worker2.ocp4.tale.net";
}
—---------------------------------------------------------------------------------------------------


Enable and start the dhcpd service
# systemctl enable dhcpd –now


After any modification to the configuration file restart the dhcpd daemon and check the log messages it generates:
# systemctl restart dhcpd
# journalctl -u dhcpd -e




Setup the physical host in AWS
This section describes how to set up a bare metal instance in AWS to be used as the physical server in which the KVM virtual machines will run.


The region used is N. Virginia as this is the more affordable one I could find.


In the AWS web site go to EC2 -> Instances -> Launch new instances.


Select the AMI “Red Hat Enterprise Linux 8 (HVM), SSD Volume Type”, 64 bit (x86) architecture must be selected.


In the Instance type page select c5n.metal (192GB RAM, 72 vCPUs)


Select the VPC and subnet where to deploy the host.  If required, create them.


Make sure the instance gets a public IP.


Go to the “Add Storage” section and set the size of the root device (/dev/sda1) to 40 GB and add a new EBS volume (/dev/sdb) of 1000 GB, select the option “delete on termination” for both volumes.


Go to Review and Launch -> Launch


Select an existing key pair or create a new one.  If a new one is created, download the key pair file and change its permissions:


$ chmod 0400 kikiriki.pem


When the instance is up and running, connect via ssh using the key pair file and the public IP address of the machine.  This public IP can change when the host is rebooted.


$ ssh -i kikiriki.pem ec2-user@35.178.191.131


Subscribe the host to Red Hat


$ sudo subscription-manager register –username <username>


Install the virtualization host group to support KVM virtual machines:


$ sudo dnf group install virtualization-host-environment


Install these additional packages:


$ sudo dnf install virt-install  libguestfs-tools tmux


Update the rest of the packages


$ sudo dnf update


In the AWS web site, go to EC2 -> Instances -> Select the newly created instance -> Instance State -> Stop Instance


When the instance shows a state of Stopped, go to Instance State -> Start instance.


When the instance is in state Running and has passed all Status checks.  Get the possibly new public IP and ssh into it


$ ssh -i kikiriki.pem ec2-user@18.170.69.216


Start a tmux session for convenience:


$ tmux


Get the name of the device associated with the 1TB disk
$ sudo lsblk|grep 1000G
Partition the 1TB disk.  Create a single partition covering the whole disk:
$ sudo cfdisk /dev/nvme1n1 


Format the partition:
$ sudo mkfs.xfs /dev/nvme1n1p1


Mount the partition in /var/lib/libvirt/images
* Get the partition ID
$ sudo blkid
* Add an entry like the following to the /etc/fstab file
UUID=95534019-3…e04d98199 /var/lib/libvirt/images  xfs         defaults            0 0
* Restrict the permissions of the directory
$ sudo chmod 0751 /var/lib/libvirt/images/
* Apply the SeLinux file tags to the directory
$ sudo restorecon -R -Fv /var/lib/libvirt/images/ 
Create an storage pool for KVM VMs:
   $  sudo virsh pool-define-as default dir --target /var/lib/libvirt/images/
   $  sudo virsh pool-build default
   $  sudo virsh pool-start default
   $  sudo virsh pool-autostart default
   $  sudo virsh pool-list --all --details
   
Start and enable the libvirtd service
$ sudo systemctl start libvirtd
$ sudo systemctl enable libvirtd


Create the virtual networks: routable and provisioning using the xml definitions at the top of the doc


Import the VM providing DHCP and DNS services.
* Copy the qcow2 and the xml definition files:
# scp -i benaka.pem /var/lib/libvirt/images/dhns.qcow2 \
   dhns.xml ec2-user@44.198.53.71:
$  sudo mv dhns.qcow2 /var/lib/libvirt/images
$  sudo ls -l /var/lib/libvirt/images
$  sudo chown qemu: /var/lib/libvirt/images/dhns.qcow2
$  sudo virsh define dhns.xml
$ sudo virsh start dhns


Copy the rhel8 qcow2 image: 
# scp -i benaka.pem rhel-8.5-x86_64-kvm.qcow2 ec2-user@44.198.53.71:




Redfish based architecture
In this architecture there is no provisioning network, only a routable network is required.  
The redfish protocol must be used.
Sushy tools provides the Redfish protocol service
https://docs.openstack.org/sushy-tools/latest/
https://gist.github.com/williamcaban/e5d02b3b7a93b497459c94446105872c


Prepare the physical host
A physical host with libvirt/KVM virtual machines will be used in this demonstration.
Prepare the physical host as described in section Setup the physical host in AWS


The default virtual network in libvirt can be used, but in this case a specific network is created for the OCP cluster.  Follow the instructions in section Create the routable baremetal and provisioning networks in KVM, but only create the baremetal network.


Create a non privileged user and provide that user with sudo privileges::
# useradd kni
# passwd kni
# echo "kni ALL=(root) NOPASSWD:ALL" | tee -a /etc/sudoers.d/kni
# chmod 0440 /etc/sudoers.d/kni


Modify the user to add the libvirt group to the newly created user:
$ sudo usermod --append --groups libvirt kni

Login and validate user can execute virsh commands
$ su - kni
$ $ virsh -c qemu:///system list --all
 Id   Name   State
-----------------------
 -        dhns   shut off

Install sushy-tools
In the physical host Install the following packages:
$ sudo dnf install libvirt-devel gcc python3-virtualenv httpd-tools


Create a python virtual environment 
$ virtualenv-3 sushy-tools
$ . sushy-tools/bin/activate


Install sushy tools
$ pip3 install sushy-tools libvirt-python


Setup sushy-tools
Create an SSL certificate to encrypt redfish communications (sushy tools).  Data entered to describe the certificate may or may not be relevant:
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


Review certificate:
$ openssl x509 -in sushy.cert -text -noout|less


Create a user file with a single user for basic HTTP authentication, that will be used by susy-tools.  Queries to the sushy-tools service will need to authenticate with this user.
$ htpasswd -c -B -b htusers admin password


Create a configuration file like the following.  Use the right values for the SSL certificate path, the http basic users file, etc.
The file specified in the section SUSHY_EMULATOR_BOOT_LOADER_MAP must be present in the system.  In the case of RHEL8 this file belongs to the package edk2-ovmf.


#/etc/sushy-emulator.conf
# Listen on all local IP interfaces
SUSHY_EMULATOR_LISTEN_IP = u'0.0.0.0'


# Bind to TCP port 8080
SUSHY_EMULATOR_LISTEN_PORT = 8080


# Serve this SSL certificate to the clients
# SUSHY_EMULATOR_SSL_CERT = u'sushy.cert'
SUSHY_EMULATOR_SSL_CERT = u'sushy.cert'


# If SSL certificate is being served, this is its RSA private key
# SUSHY_EMULATOR_SSL_KEY = u'sushy.key'
SUSHY_EMULATOR_SSL_KEY = u'sushy.key'


# If authentication is desired, set this to an htpasswd file.
SUSHY_EMULATOR_AUTH_FILE = u'htusers'


# The OpenStack cloud ID to use. This option enables OpenStack driver.
SUSHY_EMULATOR_OS_CLOUD = None


# The libvirt URI to use. This option enables libvirt driver.
SUSHY_EMULATOR_LIBVIRT_URI = u'qemu:///system'


# Workaround for BZ by @alosadagrande - 20.05.2021
# https://bugzilla.redhat.com/show_bug.cgi?id=1957387
SUSHY_EMULATOR_IGNORE_BOOT_DEVICE = True


# The map of firmware loaders dependant on the boot mode and
# system architecture
SUSHY_EMULATOR_BOOT_LOADER_MAP = {
        u'UEFI': {
            u'x86_64': u'/usr/share/OVMF/OVMF_CODE.secboot.fd'
        },
        u'Legacy': {
            u'x86_64': None,
            u'aarch64': None
        }
}


# This map contains statically configured virtual media resources.
# These devices ('Cd', 'Floppy', 'USBStick') will be exposed by the
# Manager(s) and possibly used by the System(s) if system emulation
# backend supports boot image configuration.
#
# If this map is not present in the configuration, the following configuration
# is used:
SUSHY_EMULATOR_VMEDIA_DEVICES = {
        u'Cd': {
            u'Name': 'Virtual CD',
            u'MediaTypes': [
                u'CD',
                u'DVD'
            ]
        }
}


Start and test sushy tools
Start the service with a command like the following.  The path to the configuration file must be absolute, not relative:
$ bin/sushy-emulator --config /home/kni/sushy-tools/sushy.conf 
 * Serving Flask app 'sushy_tools.emulator.main' (lazy loading)
 * Environment: production
   WARNING: This is a development server. Do not use it in a production deployment.
   Use a production WSGI server instead.
 * Debug mode: off
 * Running on all addresses.
   WARNING: This is a development server. Do not use it in a production deployment.
 * Running on https://172.31.75.189:8080/ (Press CTRL+C to quit)


In another terminal test the service with curl, the URL is obtained from the output above:
$ curl -k --user admin:password  https://172.31.75.189:8080/redfish/v1/Systems/                                                                             
{
"@odata.type": "#ComputerSystemCollection.ComputerSystemCollection",
"Name": "Computer System Collection",
"Members@odata.count": 1,
"Members": [
                {
                    "@odata.id": "/redfish/v1/Systems/44e3c29b-325e-4ad3-9859-c29233204a8a"
                }
],
        "@odata.context": "/redfish/v1/$metadata#ComputerSystemCollection.ComputerSystemCollection",                                                                                         
        "@odata.id": "/redfish/v1/Systems",
        "@Redfish.Copyright": "Copyright 2014-2016 Distributed Management Task Force, Inc. (DMTF). For the full DMTF copyright policy, see http://www.dmtf.org/about/policies/copyright."


Add firewall rules to allow access to sushy-tools
In order for the bootstrap VM to be able to control the cluster VMs via redfish protocol a firewall rule needs to be added to the physical host: 
$ sudo firewall-cmd --add-port 8080/tcp --zone=libvirt --permanent
$ sudo firewall-cmd --reload
$ sudo firewall-cmd --list-all --zone libvirt
Setup DNS service
A DNS server is required to resolve the names of the hosts in the cluster and some additional service names.  Follow the instructions in the section Creating a support VM.
Alternatively the support VM can be imported following the instructions in section Import the VM providing DHCP and DNS services.
The DHCP is optional, in this example is used to provide network configuration for the provisioning VM, the nodes in the OCP cluster don’t use it.
Create the provisioning VM
Create the provisioning VM following the instructions in section Create the provisioning VM, but in this case the command used to create the VM is slightly different. 
* The reference to the provision network is removed since no such network is used
* Make sure the MAC address is unique and is the one used by the DHCP server for this VM in the support VM


$ sudo virt-install --name=provision --vcpus=4 --ram=24096 \
  --disk path=/var/lib/libvirt/images/provision.qcow2,bus=virtio,size=120  \
  --os-variant rhel8.5 --cpu host-passthrough,cache.mode=passthrough  \
  --network network=chucky,model=virtio,mac=52:54:00:9d:41:3c \
  --boot hd,menu=on --graphics vnc,listen=0.0.0.0 --noreboot \
  --noautoconsole --console pty,target_type=virtio
Create the empty cluster hosts
https://docs.openstack.org/sushy-tools/latest/user/dynamic-emulator.html
Follow the instructions in sections Create the 3 empty master nodes and Create two empty worker nodes
The virt-install command is slightly different from the one in the sections above because it does not link the host to the provision network, which is not used in this case:
# for x in {1..3}; do echo $x; virt-install --name bmipi-master${x} --vcpus=4  \ 
--ram=16384 --disk path=/var/lib/libvirt/images/BMIPI-master${x}.qcow2,bus=virtio,size=40 \
--os-variant rhel8.5 --network network=chucky,model=virtio,mac=52:54:00:a9:6d:7${x} \
--boot hd,menu=on --graphics vnc,listen=0.0.0.0 --noreboot  --noautoconsole; done


# for x in {1..2}; do echo $x; virt-install --name bmipi-worker${x} --vcpus=4 \
 --ram=16384 --disk path=/var/lib/libvirt/images/BMIPI-worker${x}.qcow2,bus=virtio,size=40  \
--os-variant rhel8.5 --network network=chucky,model=virtio,mac=52:54:00:a9:6d:9${x} \        --boot hd,menu=on --graphics vnc,listen=0.0.0.0 --noreboot --noautoconsole; done


Check that the VMs are detected by susy-tools:
$ curl -k --user admin:password https://172.31.75.189:8080/redfish/v1/Systems/
{
        "@odata.type": "#ComputerSystemCollection.ComputerSystemCollection",
        "Name": "Computer System Collection",
        "Members@odata.count": 7,
        "Members": [
            
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


The character string is the UUID of the VM, should match the output from the following command:
$ sudo virsh list --all --name --uuid
44e3c29b-325e-4ad3-9859-c29233204a8a dhns                              
335fe8b6-7ae4-4bf8-a492-8e11873be01b provision                         
245184e0-9e76-42a7-b8c1-f8f64164bc82 bmipi-master1                     
a95336a0-7213-4df4-a0cd-1796aba76ecb bmipi-master2                     
36a19373-be1c-448c-8b4e-91ef597cb8e3 bmipi-master3                     
11adbf9b-6f09-4502-bd5d-3d4d4e4a4895 bmipi-worker1                     
639e3f63-72d8-4a48-9052-3c1175a7a4ea bmipi-worker2


Prepare the provision VM
Follow the instructions in sections:
Set up virtualization in the provisioning VM
Preparing the provisioning node for OpenShift Container Platform installation
Configure networking in the provisioning VM. Apply here only the parts referring to the baremetal network.
Get the pull secret, Openshift installer and oc client
 
Create the install-config.yaml file
Each host requires the VM’s UUID and its MAC address, use the following command to get that information:


$ for x in bmipi-master1 bmipi-master2 bmipi-master3 bmipi-worker1 bmipi-worker2; do echo -n "${x} "; sudo virsh domuuid $x|tr "\n" " "; sudo virsh domiflist $x| awk '/52:54/ {print $NF}'; done
bmipi-master1: 245184e0-9e76-42a7-b8c1-f8f64164bc82  52:54:00:a9:6d:71
bmipi-master2: a95336a0-7213-4df4-a0cd-1796aba76ecb  52:54:00:a9:6d:72
bmipi-master3: 36a19373-be1c-448c-8b4e-91ef597cb8e3  52:54:00:a9:6d:73
bmipi-worker1: 11adbf9b-6f09-4502-bd5d-3d4d4e4a4895  52:54:00:a9:6d:91
bmipi-worker2: 639e3f63-72d8-4a48-9052-3c1175a7a4ea  52:54:00:a9:6d:92


Adding the section rootDeviceHints is required, unlike when doing the installation using a provisioning network.


apiVersion: v1
baseDomain: tale.net
metadata:
  name: ocp4
networking:
  networkType: OVNKubernetes
  machineCIDR: 192.168.30.0/24
compute:
- name: worker
  replicas: 2
controlPlane:
  name: master
  replicas: 3
  platform:
        baremetal: {}
platform:
  baremetal:
        apiVIP: 192.168.30.100
        ingressVIP: 192.168.30.110
        provisioningNetwork: "Disabled"
        externalBridge: baremetal
        hosts:
          - name: bmipi-master1
              role: master
              bmc:
                  address: redfish-virtualmedia://172.31.75.189:8080/redfish/v1/Systems/2451…4bc82
                  disableCertificateVerification: True
                  username: admin
                  password: password
              bootMACAddress: 52:54:00:a9:6d:71
              rootDeviceHints:
                  deviceName: /dev/vda
          - name: bmipi-master2
              role: master
              bmc:
                  address: redfish-virtualmedia://172.31.75.189:8080/redfish/v1/Systems/a95336…6ec                  disableCertificateVerification: True
                  username: admin
                  password: password
              bootMACAddress: 52:54:00:a9:6d:72
          rootDeviceHints:
                  deviceName: /dev/vda
          - name: bmipi-master3
              role: master
              bmc:
                  address: redfish-virtualmedia://172.31.75.189:8080/redfish/v1/Systems/36a1…7cb8e
                  disableCertificateVerification: True
                  username: admin
                  password: password
              bootMACAddress: 52:54:00:a9:6d:73
          rootDeviceHints:
                  deviceName: /dev/vda
          - name: bmipi-worker1
              role: worker
              bmc:
                  address: redfish-virtualmedia://172.31.75.189:8080/redfish/v1/Systems/11ad…4a489
                  disableCertificateVerification: True
                  username: admin
                  password: password
              bootMACAddress: 52:54:00:a9:6d:91
          rootDeviceHints:
                  deviceName: /dev/vda
          - name: bmipi-worker2
              role: worker
              bmc:
                  address: redfish-virtualmedia://172.31.75.189:8080/redfish/v1/Systems/639…5a7a4e
                  disableCertificateVerification: True
                  username: admin
                  password: password
              bootMACAddress: 52:54:00:a9:6d:92
          rootDeviceHints:
                  deviceName: /dev/vda
pullSecret: ‘’
sshKey: |




Install the Openshift cluster
Create a directory and copy the install-config.yaml file into it.  This is done to make sure a copy of the install-cofig.yaml file survives the installation. The surviving copy is the one kept in the main directory:
$ mkdir ocp4
$ cp install-config.yaml ocp4/


If a previous failed install happened, remove old bootstrap resources if any are left over from a previous deployment attempt
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
The error about missing volume vda is normal, nothing to worry about.


Run the installation from the provisioning host:
$ ./openshift-baremetal-install --dir ocp4/ create cluster
