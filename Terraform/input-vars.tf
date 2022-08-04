#VARIABLES
variable "region_name" {
  description = "AWS Region where the cluster is deployed"
  type = string
  default = "us-east-1"
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

variable "spot_instance" {
  description = "Determines if the AWS instance created is an spot instance or not"
  type = bool
  default = false
}

variable "ebs_disk_size" {
  description = "Size, in Megabytes, of the additional EBS disk attached to the metal instance"
  type = number
  default = 1000
}

variable "resources_id" {
  description = "ID string to add add the end of AWS resource names so they can be more easily associated with a particular project"
  type = string
  default = ""
}

#LOCALS
locals {
#Fixed short random string
suffix = var.resources_id == "" ? random_string.strand.result : var.resources_id
}
