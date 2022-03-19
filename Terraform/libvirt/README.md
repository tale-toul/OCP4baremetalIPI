# KVM based infrastructure with terraform

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
## Deploying the infrastructure

* Add the RHEL 8 disk image 

     Get the qcow2 image for RHEL 8 from [https://access.redhat.com/downloads/](https://access.redhat.com/downloads/), click on Red Hat Enterprise Linux 8 and download Red Hat Enterprise Linux 8.5 KVM Guest Image.

     Copy the image to **Terraform/libvirt/rhel8.qcow2**.  This is the default location and name that the terraform template uses to locate the file, if the file is in a different location or has a different name, update the variable **rhel8_image_location** by defining the variable in the command line.
```
$ cp /home/user1/Downloads/rhel-8.5-x86_64-kvm.qcow2 Terraform/libvirt/rhel8.qcow2
```
* Check the default values for the support VM's network configuration and update accordingly, in particular the DNS server's IP, they are defined in the variable **support_net_config** in the file **Terraform/libvirt/input-vars.tf**

* The variable **number_of_workers** controls the number of worker nodes in the cluster, its default value is 3, if a different number is required assing the new value in the command line as in the example later.  At the moment the maximum number of workers that terraform can create is **10**.  The DHCP and DNS configuration files in the support VM are not dynamicaly created and will not be properly updated with the number of workers.

* If this is a fresh deployment, delete any previous **terraform.tfstate** file that may be laying around from previous attempts.

* Use a command like the following to deploy the infrastructure.  In this case a non default location for the base RHEL 8 image has been specified:
```
$ terraform apply -var="rhel8_image_location=/home/user1/Downloads/rhel-8.5-x86_64-kvm.qcow2" -var="number_of_workers=2"
```

## Created resources
The template creates the following components:
* A storage pool.- This is the defalt storage pool, of type directory, using /var/lib/libvirt/images
* 2 networks, DHCP is disable in both networks:
  * chucky.- this is the routable network 
  * provision.- this is the provisioning network, not routable 
* A disk volume using a RHEL8 image, that will be used as the base image for all the VMs that will be created
* A disk volume based on the RHEL8 base volume described above.  This volume has a size of 120GB, expressed in bytes.  Cloud init will grow the size of the base volume disk to the 120GB specified here
* A template file containing the cloud init configuration file
* A cloud init disk based on the contents of the above configuration file
* A provisioning VM.  It is initialized with the cloud init configuration on first boot; it is connected to both networks (chucky and provision); it uses the disk volume defined earlier; it can be contacted using VNC
* A support VM.  This VM will run the DHCP and DNS services for the OCP cluster. 

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

The network configuration is provided in a different file, as the [NoCloud datasource documentation](https://cloudinit.readthedocs.io/en/latest/topics/datasources/nocloud.html) states, the toplevel network key is not used in the file:
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

@#TO DO#@
The DHCP and DNS configuration files in the support VM are not dynamicaly created and will not be properly updated with a changing number of workers.
