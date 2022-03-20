# Deploy Infrastructure Resources with Terraform

## Create the AWS metal instance

The terraform template in this directory creates a metal instance in AWS to be used as a base to deploy a baremetal OCP 4 cluster using KVM/libvirt.

The elements created are:

* A VPC
* A public subnet in the first availability zone of the VPC
* An Internet gateway to provide access to and from the Intetnet to the EC2 instance created in the public zone
* A routing table that links the public subnet to the Internet Gateway
* An elastic IP for the EC2 instance 
* A list of security groups to allow access to the following ports 22(ssh), 80(http), 443(https), 5900-5010(vnc), 6443(OCP API)
* A security group to allow outbound connections from the EC2 instance and hence any VM to any port in the outside world
* An EC2 instance of type c5n.metal, powerfull enough to run the KVM VMs

## Applying the terraform template

The terraform template requires a public ssh key file in the Terraform directory, the name for the file must be __ssh.pub__, if a different name is used, the variable **ssh-keyfile** must be defined with the new filename.  This public ssh keyfile will be injected into the EC2 instance so the ec2-user can later connect via ssh.

The AWS region to deploy the infrastructure can be defined with the variable **region_name**, the default region is **us-east-1** (N. Virginia).  Keep in mind that the same infrastructure may incur different costs depending on the region used.

The type of AWS instance created is defined with the variable **instance_type**, by default the instance type created is **c5n.metal**.  If the variable is defined with a different value, it must be a metal type instance for example g4dn.metal

Apply the template to create the infrastructure with a command like:
```
$ terraform apply -var="region_name=us-east-1" -var="ssh-keyfile=baremetal-ssh.pub" -var="instance_type=c5.metal"
```
If the terraform variables are used with non default values, keep a copy of the command so the same values are used to destroy the infrastructure:
```
$ echo !! > terraform_apply.txt
```

When all the infrastructure components have been created, output variables are shown, of special interest is the public IP of the EC2 instance:

```
baremetal_public_ip = "4.83.45.254"
bastion_private_ip = "172.20.12.225"
public_subnet_cidr_block = "172.20.0.0/20"
region_name = "us-east-1"
vpc_cidr = "172.20.0.0/16"
```
## Connecting to the EC2 instance

It may take a few minutes after creation for the EC2 instance to be ready to receive connections.

Ssh is used to open a shell with the EC2 instance created by terraform.  

The elements required are:
* The private part of the ssh key injected earlier 
* The user to connect is **ec2-user**
* The public IP returned by terraform output, can also be obtained with the command
```
$ terraform output baremetal_public_ip
"4.83.45.254"
```
The command to connect would be something like:
```
$ ssh -i baremetal-ssh.priv ec2-user@4.83.45.254
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
