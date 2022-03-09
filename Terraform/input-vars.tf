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

variable "rhel-ami" {
  description = "RHEL 8 AMI on which the EC2 instances are based on, depends on the region"
  type = map
  default = {
    eu-central-1   = "ami-050837049b91c9669"
    eu-west-1      = "ami-059bccc3f1258ac87"
    eu-west-2      = "ami-06c5f99e89e55e57b"
    eu-west-3      = "ami-0b253993b4e203da1"
    eu-south-1     = ""
    eu-north-1     = "ami-040cdf30c60564b9b"
    us-east-1      = "ami-019599717e2dd5baa"
    us-east-2      = "ami-005074b2b824595f4"
    us-west-1      = "ami-0857cd00e87b26735"
    us-west-2      = "ami-04e900eb50a68a74b"
    sa-east-1      = ""
    ap-south-1     = ""
    ap-northeast-1 = ""
    ap-northeast-2 = ""
    ap-southeast-1 = ""
    ap-southeast-2 = ""
    ca-central-1   = "ami-002faace35df3cac9"
  }
}

#LOCALS
locals {
#Fixed short random string
suffix = "${random_string.strand.result}"
}
