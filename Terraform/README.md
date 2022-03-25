# Deploy Infrastructure Resources with Terraform

## Create the AWS metal instance

The terraform template in this directory creates an EC2 metal instance in AWS to be used as a base to deploy the libvirt/KVM resources required to deploy a baremetal OCP 4 cluster using baremetal IPI installation method

## Module initialization

Before running terraform for the first time, the modules used by the template must be downloaded and initialized, this requires an active Internet connection.  

Run the following command in the directory where the terraform templates reside.  The command can be safely run many times, it will not trampled previous executions:
```
$ cd libvirt
$ terraform init

Initializing the backend...
```
Terraform needs access to credentials for an AWS user with privileges to create resources, these can be defined in a file containing the access key ID and the access key secret with the following format. Put this file in ~/.aws/credentials:
```
[default]
aws_access_key_id=xxxx
aws_secret_access_key=xxxx
```

## Applying the terraform template

Some variables are defined in the Terraform/input-vars.tf** that can be used to modify some configuration parameters.  The most relevan of these are:

* **region_name**.- AWS Region where the EC2 instance and other resources are created.  Keep in mind that the same infrastructure may incur different costs depending on the region.

     Default value: us-east-1

* **ssh-keyfile**.- Name of the file with the public part of the SSH key to transfer to the EC2 instance.  This public ssh keyfile will be injected into the EC2 instance so the ec2-user can later connect via ssh using the corresponding private part.

     Default value:  ssh.pub

* **instance_type**.- AWS instance type for the hypervisor machine.  This must be a metal instance.

     Default value: c5n.metal

Copy a public ssh key file in the Terraform directory, the default expected name for the file is **ssh.pub**, if a different name is used, the variable **ssh-keyfile** must be updated accordingly.  

Apply the template to create the infrastructure with a command like:
```
$ terraform apply -var="region_name=us-east-1" -var="ssh-keyfile=baremetal-ssh.pub" -var="instance_type=c5.metal"
```
If the terraform variables are used with non default values, keep a copy of the command so the same values are used to destroy the infrastructure:
```
$ echo !! > terraform_apply.txt
```

When all the infrastructure components have been created, output variables are shown, of special interest is the EC2 instance's public IP:

```
baremetal_public_ip = "4.83.45.254"
bastion_private_ip = "172.20.12.225"
public_subnet_cidr_block = "172.20.0.0/20"
region_name = "us-east-1"
vpc_cidr = "172.20.0.0/16"
```
## Connecting to the EC2 instance

It may take a few minutes after creation for the EC2 instance to be ready and accept connections.

Ssh is used to connect to the EC2 instance created by terraform.  

The elements required are:
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

When the resources are not required anymore they can be easily removed using terraform, just run a command similar to the one used to create them using the subcommand **destroy**.  

Destroying the AWS resources will also remove any Openshift or libvirt resources created in the EC2 instance.
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
