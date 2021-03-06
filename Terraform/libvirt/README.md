# Libvirt/KVM based infrastructure with terraform

This directory contains the terraform templates and support files required to deploy the KVM/libvirt based infrastructure components required to deploy the baremetal IPI OCP cluster.

## Module initialization

Before running terraform for the first time, the modules used by the template must be downloaded and initialized, this requires an active Internet connection.  

Run the following command in the directory where the terraform templates reside.  The command can be safely run many times, it will not trampled previous executions:
```
$ cd libvirt
$ terraform init

Initializing the backend...

Initializing provider plugins...
- terraform.io/builtin/terraform is built in to Terraform
- Reusing previous version of dmacvicar/libvirt from the dependency lock file
- Reusing previous version of hashicorp/template from the dependency lock file
- Using previously-installed dmacvicar/libvirt v0.6.14
- Using previously-installed hashicorp/template v2.2.0

Terraform has been successfully initialized!

You may now begin working with Terraform. Try running "terraform plan" to see
any changes that are required for your infrastructure. All Terraform commands
should now work.

If you ever set or change modules or backend configuration for Terraform,
rerun this command to reinitialize your working directory. If you forget, other
commands will detect it and remind you to do so if necessary.
```
## Input variables

Many aspects of the infrastructure created by terraform can be modified by assigning different values to the variables defined in the file **input-vars.tf**

All variables contain default values so it is not neccessary to modify them in order to create a funtioning infrastructure. 

Most of the input variables used to configure the infrastructure are defined in the inpu-vars.tf file to simplify and organize the information, even if they are not used by terraform.  For example the variable **ocp_version** is not used by terraform however is defined here.  Most of the input variables are also defined as output variables so they can be used later by the ansible playbooks.

The list of variables its purpose and default value are:

* **rhel8_image_location**.- Path and filename to the qcow2 image to be used as the base for the operating system in the support and provision VMs

     Default value: rhel8.qcow2

* **provision_resources**.- Object variable with two fields: 

     memory.- The ammount of memory in MB to be assigned to the provision VM

     vcpu.- The number of CPUS to be assigned to the provision VM

     Default values: memory = 24576    vcpu = 4

* **support_resources**.-  Object variable with two fields:

     memory.- The ammount of memory in MB to be assigned to the support VM

     vcpu.- The number of CPUS to be assigned to the support VM

     Default values: memory = 24576    vcpu = 4

* **master_resources**.- Object variable with two fields:

     memory.- The ammount of memory in MB to be assigned to the master VMs

     vcpu.- The number of CPUS to be assigned to the master VMs

     Default values: memory = "16384"   vcpu = 4

* **worker_resources**.- Object variable with two fields:

     memory.- The ammount of memory in MB to be assigned to the worker VMs

     vcpu.- The number of CPUS to be assigned to the worker VMs

     Default values: memory = "16384"   vcpu = 4

* **number_of_workers**.- How many worker nodes will be created by terraform.  The number must be between 1 and 16.

     Default value: 3

* **chucky_net_addr**.- Network address for the routable network where all VMs are connected

     Default value: 192.168.30.0/24

* **provision_net_addr**.- Network address for the provisioning network where cluster nodes and provisioning host are connected.

     Default value: 192.168.14.0/24

* **support_net_config_nameserver**.- IP address for the external DNS server used by the support host.  This name server is initialy used to resolve host names so the support host can register and install packages.

     Default value: 8.8.8.8

* **dns_zone**.- DNS base zone for the Openshift cluster.  This is a private zone that is not resolvable outside the virtual networks or EC2 instance so any value can be used.

     Default value:  tale.net

*  **cluster_name**.- Used as the subdomain for the whole cluster DNS name.  For example for a cluster name of **ocp4** and a dns zone of **tale.net** the whole cluster domain is **ocp4.tale.net**

     Default value: ocp4

* **ocp_version**.- Openshift version to be deployed.  Available versions can be seen [here](https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/) 

     Default value: 4.9.5

* **provision_mac**.- MAC address for provision VM NIC in the routable (chucky) network.  This is used in the DHCP server to assign a known IP to the provision VM in the chucky network.  The letters in the MACs should be in lowercase.

     Default value: 52:54:00:9d:41:3c

* **master_provision_mac_base**.- MAC address common part for the master NICs in the provisioning network.  The last character for the MAC address will be assigned dynamically by terraform and ansible allowing the creation of up to 16 addresseses, from 52:54:00:74:dc:a0 to 52:54:00:74:dc:af.  The letters in the MACs should be in lowercase.

     Default value: 52:54:00:74:dc:a

* **master_chucky_mac_base**.- MAC address common part for the master NICs in the chucky network.  The last character for the MAC address will be assigned dynamically by terraform and ansible allowing the creation of up to 16 addresseses, from 52:54:00:a9:6d:70 to 52:54:00:a9:6d:7f.  The letters in the MACs should be in lowercase.

     Default value: 52:54:00:a9:6d:7

* **worker_provision_mac_base**.- MAC address common part for the worker NICs in the provisioning network.  The last character for the MAC address will be assigned dynamically by terraform and ansible allowing the creation of up to 16 addresseses, from 52:54:00:74:dc:d0 to  52:54:00:74:dc:df.  The letters in the MACs should be in lowercase.

     Default value: 52:54:00:74:dc:d

* **worker_chucky_mac_base**.- MAC address common part for the worker NICs in the chucky network.  The last character for the MAC address will be assigned dynamically by terraform and ansible allowing the creation of up to 16 addresseses, from 52:54:00:a9:6d:90  to 52:54:00:a9:6d:9f.  The letters in the MACs should be in lowercase.

     Default value: 52:54:00:a9:6d:9

* **architecture**.- This variable defines whether a provisioning network will be used (architecture = vbmc) or not (architecture = redfish).  Only two values are accepted: **vbmc** and **redfish**.  Depending on the value used, different infrastructure components will be created to support the chosen architecture model.

     Default value: vbmc

### Assigning values to input variables

There are 3 different ways in which to assign new values to the input variables describe above:

* Modify the default value in the input-vars.tf file.- All variables have a defalt line, so it is possible to just edit the file and assign the desired value by editing the **default =** line.
```
variable "chucky_net_addr" {
  description = "Network address for the routable chucky network"
  type = string
  default = "10.0.4.0/24"
}
```
* Assing the values in the command line.- Values assigned in the command line overwrite the default values in the input-vars.tf file.
```
$ terraform apply -var='number_of_workers=6'  -var='cluster_name="monaco"' -var='worker_resources={"memory":"16384","vcpu":6}' \
  -var='chucky_net_addr=192.168.55.0/24' -var='provision_net_addr=172.22.0.0/24' -var='support_net_config_nameserver=169.254.169.253' \
  -var='dns_zone=benaka.cc'
```
* Add the variable assignments to a file and call that file in the command line.  For example, the following content is added to the file monaco.vars

```
number_of_workers = 6  
cluster_name = "monaco"
worker_resources = {"memory":"16384","vcpu":6}
chucky_net_addr = "192.168.55.0/24"
provision_net_addr = "172.22.0.0/24"
support_net_config_nameserver = "169.254.169.253"
dns_zone = "benaka.cc"
```
And the terraform command to use those definitions is:
```
$ terraform apply -var-file monaco.vars
```

## Deploying the infrastructure

* Add the RHEL 8 disk image 

     Get the qcow2 image for RHEL 8 from [https://access.redhat.com/downloads/](https://access.redhat.com/downloads/), click on Red Hat Enterprise Linux 8 and download Red Hat Enterprise Linux 8.5 KVM Guest Image.

     Keep in mind that the RHEL image is more than 700MB in size so a fast Internet connection is recommended.

     Copy the image to **Terraform/libvirt/rhel8.qcow2**.  This is the default location and name that the terraform template uses to locate the file, if the file is in a different location or has a different name, update the variable **rhel8_image_location** by defining the variable in the command line.
```
$ cp /home/user1/Downloads/rhel-8.5-x86_64-kvm.qcow2 Terraform/libvirt/rhel8.qcow2
```

* If this is a fresh deployment, delete any previous **terraform.tfstate** file that may be laying around from previous attempts.

* Use a command like the following to deploy the infrastructure.  
```
$ terraform apply -var-file monaco.vars
```

## Created resources
The template creates the following components:
* 1 or 2 networks, depending on the value of the **architecture** variable.  DHCP is disable in both networks:
  * chucky.- this is the routable network.  This is always created.
  * provision.- this is the provisioning network, not routable.  Created when `architecture=vbmc` which is the default value.
* A base disk volume using a RHEL8 image, this will be used as the base image for all the VMs that are created later.
* A disk volume based on the RHEL8 base volume that is used as the OS disk for the provision VM.  This volume has a size of 120GB, expressed in bytes.  Cloud init will grow the size of the base volume disk to the 120GB specified here
* A cloud init disk for the provision VM, containing the user data and network configuration defined by two template files.
* A provision VM.  It is initialized with cloud init on first boot; it is connected to networks chucky and provision (if available); it uses the disk volume defined earlier
* A disk volume based on the RHEL8 base volume that will be the OS disk for the support VM.  
* A cloud init disk for the support VM, containing the user data and network configuration defined by two template files.
* A support VM.  This VM runs the DHCP and DNS services for the OCP cluster.  It is only connected to the routable (chucky) network.
* 3 empty disk volumes that will be the OS disks for the master VMs. 
* 3 master VMs. Connected to the routable and provision (if available) networks.
* A group of empty disk volumes that will be the OS disks for the worker VMs.  The ammount created depends on the variable number_of_workers.
* A group of worker VMs.  Connected to the routable and provision (if available) networks.  The ammount created depends on the variable number_of_workers.

## Cloud init configuration
Reference documentation and examples:
* [Cloud init official module docs](https://cloudinit.readthedocs.io/en/latest/topics/modules.html)
* [Cloud init official examples](https://cloudinit.readthedocs.io/en/latest/topics/examples.html)
* [Terraform module libvirt example](https://github.com/dmacvicar/terraform-provider-libvirt/tree/main/examples/v0.13/ubuntu)
* [Red Hat cloud init documentation](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html/configuring_and_managing_cloud-init_for_rhel_8/index)

The RHEL 8 base image is capable of running cloud init on first boot to configure some of the operating system parameters, and the libvirt terraform module supports the use of cloud init when creating a VM.

Some template files containing the cloud init configuration are used.  Variables can be used to define values at rendering time.  These variables must be defined at the template file data definition block in terraform.

Ssh key authentication is the only method enable for the root user authentication, no passwords are assigned so console access is blocked. 

The support VM cloud init configuration assigns an static IP at initial configuration so this VM can be accessed via ssh immediately after creation, but the provisioning VM only gets an IP in the routable network when the DHCP service in the support VM is working, so the provisioning VM is not accessible just after creation.

The ssh key injected in the VM is the same one used in the EC2 instance 

```
$ cat provision_cloud_init.cfg 
#cloud-config
disable_root: False
ssh_pwauth: False
users:
  - name: root
    ssh_authorized_keys:
      - ${auth_key}
```
One thing that seems to be missing in the cloud init configuration file is the **growpart** section used to increase the size of the underling disk image to the size specified at VM creation time in the terraform definition.  However the default behaviour of the growpart module already applies the following configuration which increases the root partition, which is exactly the desired action in this situation.
```
growpart:
  mode: auto
  devices: ['/']
  ignore_growroot_disabled: false
```

The network configurations are provided in separate files, as the [NoCloud datasource documentation](https://cloudinit.readthedocs.io/en/latest/topics/datasources/nocloud.html) states, the toplevel network key is not used in the file:
```
version: 1
config:
- type: physical
  name: eth0
  subnets:
  - address: ${address}
    dns_nameservers: 
    - ${nameserver}
    gateway: ${gateway}
    type: static
```
The network configuration [template](https://www.terraform.io/language/functions/templatefile) for the provision VM uses [terraform conditional statements](https://www.terraform.io/language/expressions/strings#directives) so the rendered configuration is adapted depending on whether a provisioning network is required or not.

If the variable **architecture=vbmc** the provisioning network is used so two network interfaces are configured.  If the variable has any other value, actually the variable has a validation statement that only allows it to get the values **vbmc** and **redfish**, then only one network interface will be configured in the routable network using DHCP:

```
version: 1
config:
- type: physical
  name: eth0
- type: bridge
%{~ if architecture == "vbmc"}
  name: provision
%{~ else }
  name: chucky
%{ endif }
  bridge_interfaces:
    - eth0
  subnets:
%{~ if architecture == "vbmc"}
    - type: static
      address: ${ironiq_addr}
%{~ else }
    - type: dhcp
%{ endif }
%{~ if architecture == "vbmc"}
- type: physical
  name: eth1
- type: bridge
  name: chucky
  bridge_interfaces:
    - eth1
  subnets:
    - type: dhcp
%{~ endif ~}
```

## Dependencies 
This terraform template depends on the output variables from the main terraform template that creates the metal instance in AWS.  The output variables are obtained from a local backend:

```
data "terraform_remote_state" "ec2_instance" {
  backend = "local"

  config = {
    path = "../terraform.tfstate"
  }
}
```
Later in the template some of the output variables are used to define components.  In the following example the URI to connect to the libvirt service in the remote EC2 host gets the IP and the public ssh key from the output variables:
```
provider "libvirt" {
  uri = "qemu+ssh://ec2-user@${data.terraform_remote_state.ec2_instance.outputs.baremetal_public_ip}/system?keyfile=../${data.terraform_remote_state.ec2_instance.outputs.ssh_certificate}"
}
```
The result from applying the variables is something like:
```
  uri = "qemu+ssh://ec2-user@3.223.112.4/system?keyfile=../baremetal-ssh.pub"
```

## Dynamic MAC address assignment

The MAC addresses for worker nodes are dynamically created using a base and a loop variable in the terraform template file libvirt.tf

The count.index variable takes values from 0 to 16, that must be converted to an hexadecimal character 0 to a, this is done with the [format terraform function](https://www.terraform.io/language/functions/format):

```
network_interface {
  network_id = libvirt_network.chucky.id
  mac        = format("${var.worker_chucky_mac_base}%x",count.index)
}
```
A similar formating trick is used in ansible, for the same purposes.

## Conditional creation of the provision network

Depending on the value of the input variable **architecture** the provision network is created or not.

If **architecture="vbmc"**, which is the default, the routable and the provision networks are created and the provision host, master and worker nodes are connected to both of them.

If **architecture="redfish"** only the routable network is created and all hosts are connected to it.

The logic is implemented using the count trick.  When **architecture="vbmc"** a count of one resource is created, otherwise a count of zero resources is created:
```
resource "libvirt_network" "provision" {
  count = var.architecture == "vbmc" ? 1 : 0
...
```
The creation of the provision and cluster master and workers has to take into account if the provision network exists or not to create a network interface connected to that network, or not.  
The logic to create the provision NIC uses a **dynamic** block with a for_each loop.  The list of network resources in **libvirt_network.provision** is converted to a set which is what for_each can use.  That list can only have either 1 or zero elements as was described above, in case the list has no element the NIC will not be created, but if the list has one element, the NIC will be created.  It is a similar logic as the use of _count_ earlier, but used for blocks within a resource, where _count_ cannot be used.
```
  dynamic "network_interface" {
    for_each = toset(libvirt_network.provision[*].id)
    content {
      network_id = network_interface.key
    }
  }
```
The cloud init network configuration applied to the provision VM also changes depending on whether the provision network exists or not.  The details of this configuration are explained in section [Cloud init configuration](#cloud-init-configuration)


## Troubleshooting

### Missing iptables chains

Sometimes during the creation of resources an error like the following appears:
```
 Error: error creating libvirt network: internal error: Failed to apply firewall rules /usr/sbin/iptables -w --table filter --insert LIBVIRT_INP --in-interface chucky --protocol tcp --destination-port 67 --jump ACCEPT: iptables: No chain/target/match by that name.
??? 
??? 
???   with libvirt_network.chucky,
???   on libvirt.tf line 28, in resource "libvirt_network" "chucky":
???   28: resource "libvirt_network" "chucky" {
```
Checking the firewall rules in the metal instance shows an empty list, which matches the error above that some table target or match is missing:
```
$ sudo iptables -L -nv
Chain INPUT (policy ACCEPT 252K packets, 794M bytes)
 pkts bytes target     prot opt in     out     source               destination         

Chain FORWARD (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination         

Chain OUTPUT (policy ACCEPT 190K packets, 12M bytes)
 pkts bytes target     prot opt in     out     source               destination 
```
Checking the libvirtd service also shows the iptables error messages:
```
$ sudo systemctl status libvirtd
??? libvirtd.service - Virtualization daemon
   Loaded: loaded (/usr/lib/systemd/system/libvirtd.service; enabled; vendor preset: enabled)
   Active: active (running) since Thu 2022-04-07 07:07:06 UTC; 11min ago
     Docs: man:libvirtd(8)
           https://libvirt.org
 Main PID: 42387 (libvirtd)
    Tasks: 19 (limit: 32768)
   Memory: 806.6M
   CGroup: /system.slice/libvirtd.service
           ??????42387 /usr/sbin/libvirtd --timeout 120
           ??????43705 /usr/sbin/dnsmasq --conf-file=/var/lib/libvirt/dnsmasq/default.conf --leasefile-ro --dhcp-script=/usr/libexec/libvirt_leaseshelper
           ??????43707 /usr/sbin/dnsmasq --conf-file=/var/lib/libvirt/dnsmasq/default.conf --leasefile-ro --dhcp-script=/usr/libexec/libvirt_leaseshelper

Apr 07 07:07:09 ip-172-20-8-165.ec2.internal libvirtd[42387]: libvirt version: 6.0.0, package: 37.1.module+el8.5.0+13858+39fdc467 (Red Hat, Inc. <http://bugzilla.redhat.com/bugzilla>, 2022->
Apr 07 07:07:09 ip-172-20-8-165.ec2.internal libvirtd[42387]: hostname: ip-172-20-8-165.ec2.internal
Apr 07 07:07:09 ip-172-20-8-165.ec2.internal libvirtd[42387]: internal error: Failed to apply firewall rules /usr/sbin/iptables -w --table filter --insert LIBVIRT_INP --in-interface virbr0 >
Apr 07 07:09:30 ip-172-20-8-165.ec2.internal libvirtd[42387]: internal error: Failed to apply firewall rules /usr/sbin/iptables -w --table filter --insert LIBVIRT_INP --in-interface chucky >
Apr 07 07:09:30 ip-172-20-8-165.ec2.internal libvirtd[42387]: internal error: Failed to apply firewall rules /usr/sbin/iptables -w --table filter --insert LIBVIRT_INP --in-interface provisi>
Apr 07 07:12:00 ip-172-20-8-165.ec2.internal libvirtd[42387]: internal error: Failed to apply firewall rules /usr/sbin/iptables -w --table filter --insert LIBVIRT_INP --in-interface chucky >
Apr 07 07:12:00 ip-172-20-8-165.ec2.internal libvirtd[42387]: internal error: Failed to apply firewall rules /usr/sbin/iptables -w --table filter --insert LIBVIRT_INP --in-interface provisi>
Apr 07 07:13:51 ip-172-20-8-165.ec2.internal libvirtd[42387]: failed to remove pool '/var/lib/libvirt/images': Device or resource busy
Apr 07 07:14:43 ip-172-20-8-165.ec2.internal libvirtd[42387]: internal error: Failed to apply firewall rules /usr/sbin/iptables -w --table filter --insert LIBVIRT_INP --in-interface provisi>
Apr 07 07:14:44 ip-172-20-8-165.ec2.internal libvirtd[42387]: internal error: Failed to apply firewall rules /usr/sbin/iptables -w --table filter --insert LIBVIRT_INP --in-interface chucky
```
To recreate the missing iptables rules, tables, etc. Restart the libvirtd service:
```
$ sudo systemctl restart libvirtd
```
If the service starts successfully a long list of iptables rules and chains are created, including several LIBVIRT\_<suffix> chains:
```
$ sudo iptables -L -nv
Chain INPUT (policy ACCEPT 537K packets, 1590M bytes)
 pkts bytes target     prot opt in     out     source               destination         
   66  4592 LIBVIRT_INP  all  --  *      *       0.0.0.0/0            0.0.0.0/0           
...
Chain LIBVIRT_INP (1 references)
 pkts bytes target     prot opt in     out     source               destination         
    0     0 ACCEPT     udp  --  virbr0 *       0.0.0.0/0            0.0.0.0/0            udp dpt:53
...
Chain LIBVIRT_OUT (1 references)
 pkts bytes target     prot opt in     out     source               destination         
    0     0 ACCEPT     udp  --  *      virbr0  0.0.0.0/0            0.0.0.0/0            udp dpt:53
...
```


