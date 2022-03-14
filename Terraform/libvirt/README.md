# KVM based infrastructure

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
* The variable **number_of_workers** controls the number of worker nodes in the cluster, its default value is 3, if a different number is required assing the value in the command line as in the example later.

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

## Cloud init configuration
Reference documentation and examples:
[Cloud init official module docs](https://cloudinit.readthedocs.io/en/latest/topics/modules.html)
[Cloud init official examples](https://cloudinit.readthedocs.io/en/latest/topics/examples.html)
[terraform module libvirt example](https://github.com/dmacvicar/terraform-provider-libvirt/tree/main/examples/v0.13/ubuntu)

The RHEL 8 base image is capable of running cloud init on first boot to configure some of the host parameters, and the libvirt terraform module supports the use of cloud init when creating a VM.

A template file containing the cloud init configuration is available.  Since this is a template, variables can be used to define values at rendering time.  So far only the ssh public keys is provided as a variable.  Variables must be defined at the template_file data definition block in terraform.

At the moment both a password and a ssh key are enable for root user authentication, this is a temporary solution since initially the VM has no network configuration and cannot be accessed using ssh.  If the password configuration is to be left permanently, a variable must be used instead of a literal value, for security reasons: 

```
$ cat cloud_init.cfg 
#cloud-config
disable_root: False
ssh_pwauth: True
chpasswd:
  list: |
     root:mypassword
  expire: False
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

