# Deploy Infrastructure Resources with Terraform

## Create the AWS metal instance

The terraform template in this directory creates an EC2 metal instance in AWS to be used as the base to deploy the libvirt/KVM resources required to install the OCP 4 cluster using the baremetal IPI installation method.

## Module initialization

Before running terraform for the first time, the modules used by the template must be downloaded and initialized, this requires an active Internet connection.  

Run the following command in the directory where the terraform templates reside.  The command can be safely run many times, it will not trampled previous executions:
```
$ cd libvirt
$ terraform init

Initializing the backend...
...
```
Terraform needs access to credentials for an AWS user with privileges to create resources, these can be defined in a file containing the access key ID and the access key secret with the following format. Put this file in __~/.aws/credentials__:
```
[default]
aws_access_key_id=xxxx
aws_secret_access_key=xxxx
```

## Applying the terraform template

The following variables are defined in the **Terraform/input-vars.tf** file and can be used to modify the configuration:

* **region_name**.- AWS Region where the EC2 instance and other resources are created.  Keep in mind that the same infrastructure may incur different costs depending on the region.

     Default value: us-east-1

* **ssh-keyfile**.- Name of the file in the Terraform directory with the public part of the SSH key to transfer to the EC2 instance.  This public ssh keyfile will be injected into the EC2 instance so the ec2-user can later connect via ssh using the corresponding private part.

     Default value:  ssh.pub

* **instance_type**.- AWS instance type for the hypervisor machine.  This must be a metal instance.

     Default value: c5n.metal

* **spot_instance**.- Determines if the AWS EC2 metal instance created is a spot instance (true) or not (false). Using a spot instance reduces cost but is __not guaranteed__ to be available at creation time or for long periods once created.

     Default = false

* **ebs_disk_size**.- Size in Megabytes for the additional EBS disk attached to the metal instance. This disk is used to store the libvirt/KVM Virtual Machine disks.

     Default value: 1000

* **resources_id**.- ID string to add at the end of AWS resource names so they can be more easily associated with a particular project.  If the value is empty (default) a random value will be generated and assigned to the suffix local variable.

     Default = ""


Copy a public ssh key file to the Terraform directory, the default expected name for the file is **ssh.pub**, if a different name is used, the variable **ssh-keyfile** must be updated accordingly.  

Add any of the variable definitions described above to a file, for example **ec2_metal.vars**:
```
region_name="us-east-1"
ssh-keyfile="baremetal-ssh.pub"
instance_type="c5.metal"
spot_instance=true
```
Create the resources with the following terraform command:
```
terraform apply -var-file ec2_metal.vars
```

Alternatively the variables can be defined in the command line: 
```
$ terraform apply -var region_name=us-east-1 -var ssh-keyfile=baremetal-ssh.pub -var instance_type=c5.metal -var spot_instance=true
```
If the terraform variables are defined in the command line, keep a copy of the command so the same exact values can used to destroy the infrastructure.  This step is not required if a variables file was used:
```
$ echo !! > terraform_apply.txt
```

When all the infrastructure components have been created, output variables are shown, of special interest is the EC2 instance's public IP:

```
baremetal_public_ip = "4.83.45.254"
region_name = "us-east-1"
vpc_cidr = "172.20.0.0/16"
```
## Connecting to the metal EC2 instance

It may take a few minutes after creation, for the EC2 instance to be ready and accept connections.

Ssh is used to connect to the EC2 instance created by terraform.  The elements required to connect are:
* The private part of the ssh key injected earlier 
* The user to connect is **ec2-user**
* The public IP returned by terraform output, can also be obtained with the command
```
$ terraform output baremetal_public_ip
"4.83.45.254"
```
The command to connect looks something like:
```
$ ssh -i baremetal-ssh.priv ec2-user@4.83.45.254
```
## Resources created 

The elements created are:

* A VPC
* A public subnet in the first availability zone of the VPC
* An Internet gateway to provide access to and from the Intetnet to the EC2 instance created in the public zone
* A routing table that links the public subnet to the Internet Gateway
* An elastic IP for the EC2 instance 
* A list of security groups to allow access to the following ports 22(ssh), 80(http), 443(https), 5900-5010(vnc), 6443(OCP API)
* A security group to allow outbound connections from the EC2 instance and hence any VM to any port in the outside world
* An EC2 instance of type c5n.metal, powerfull enough to run the KVM VMs

## Destroying the resources

When the resources are not required anymore they can be easily removed using terraform, just run a command similar to the one used to create them but using the **destroy** subcommand instead.

Destroying the AWS resources will also remove any Openshift or libvirt resources created in the EC2 instance.
```
terraform destroy -var-file ec2_metal.vars
```
Or if the variables were defined in the command line:
```
$ terraform destroy -var="region_name=us-east-1" -var="ssh-keyfile=baremetal-ssh.pub" -var="instance_type=c5.metal"
```

## Selecting the AMI

The AMI used to inject an Operating System in the EC2 instance is based on RHEL 8.  Terraform allows the automatic selection of the AMI based on a data source and selection filters.

In the following example the latest AMI matching the filters will be used.  The owner of the image is Red Hat "309956199498", the type of virtualization is hvm, the architecture is x86_64, and the name is expected to start with RHEL\*8.5.  If a different version of RHEL is to be used, the name should be updated accordingly.

The AMIS are region dependent, but the region is not specified because it is defined in the aws provider section, at the begginning of the terraform template.

```
data "aws_ami" "rhel8" {
  most_recent = true
  owners = ["309956199498"]
  filter {
    name = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name = "architecture"
    values = ["x86_64"]
  }
  filter {
    name = "name"
    values = ["RHEL*8.5*"]
  }
}
```
