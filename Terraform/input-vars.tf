#VARIABLES
variable "region_name" {
  description = "AWS Region where the cluster is deployed"
  type = string
  default = "us-east-1"
}

variable "vpc_name" {
  description = "Name assigned to the VPC"
  type = string
  default = "volatil"
}

variable "vpc_cidr" {
  description = "Network segment for the VPC"
  type = string
  default = "172.20.0.0/16"
}

variable "ssh-keyfile" {
  description = "Name of the file with public part of the SSH key to transfer to the EC2 instance"
  type = string
  default = "ssh.pub"
}

variable "instance_type" {
  description = "AWS instance type for the hypervisor machine"
  type = string
  default = "c5n.metal"
}

#LOCALS
locals {
#Fixed short random string
suffix = "${random_string.strand.result}"
}
