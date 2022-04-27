#PROVIDERS
provider "aws" {
  region = var.region_name
}

#Provides a source to create a short random string 
resource "random_string" "strand" {
  length = 5
  upper = false
  special = false
}

#VPC
resource "aws_vpc" "vpc" {
    cidr_block = var.vpc_cidr
    enable_dns_hostnames = true
    enable_dns_support = true

    tags = {
        Name = "${var.vpc_name}-${local.suffix}"
    }
}

resource "aws_vpc_dhcp_options" "vpc-options" {
  domain_name = var.region_name == "us-east-1" ? "ec2.internal" : "${var.region_name}.compute.internal" 
  domain_name_servers  = ["AmazonProvidedDNS"] 
}

resource "aws_vpc_dhcp_options_association" "vpc-association" {
  vpc_id          = aws_vpc.vpc.id
  dhcp_options_id = aws_vpc_dhcp_options.vpc-options.id
}

#SUBNETS
data "aws_availability_zones" "avb-zones" {
  state = "available"
}

#Public subnets
resource "aws_subnet" "subnet_pub" {
    vpc_id = aws_vpc.vpc.id
    availability_zone = data.aws_availability_zones.avb-zones.names[0]
    cidr_block = "172.20.0.0/20"
    map_public_ip_on_launch = false

    tags = {
        Name = "subnet_pub-${local.suffix}"
    }
}

#INTERNET GATEWAY
resource "aws_internet_gateway" "intergw" {
    vpc_id = aws_vpc.vpc.id

    tags = {
        Name = "intergw-${local.suffix}"
    }
}

#EIPS
resource "aws_eip" "baremetal_eip" {
  vpc = true
  instance = aws_instance.baremetal.id
  depends_on = [aws_internet_gateway.intergw]
  tags = {
      Name = "metaleip-${local.suffix}"
  }
}

#ROUTE TABLES
#Route table: Internet Gateway access for public subnets
resource "aws_route_table" "rtable_igw" {
    vpc_id = aws_vpc.vpc.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.intergw.id
    }
    tags = {
        Name = "rtable_igw-${local.suffix}"
    }
}

#Route table associations
resource "aws_route_table_association" "rtabasso_subnet_pub" {
    subnet_id = aws_subnet.subnet_pub.id
    route_table_id = aws_route_table.rtable_igw.id
}

#SECURITY GROUPS
resource "aws_security_group" "sg-ssh-in" {
    name = "ssh-in"
    description = "Allow ssh connections"
    vpc_id = aws_vpc.vpc.id

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "sg-ssh"
    }
}

resource "aws_security_group" "sg-web-in" {
    name = "web-in"
    description = "Allow http and https inbound connections from anywhere"
    vpc_id = aws_vpc.vpc.id

    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "sg-web-in"
    }
}

resource "aws_security_group" "sg-api-in" {
    name = "api-in"
    description = "Allow inbound connections to the API endopoint from anywhere"
    vpc_id = aws_vpc.vpc.id

    ingress {
        from_port = 6443
        to_port = 6443
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "sg-api-in"
    }
}


resource "aws_security_group" "sg-vnc-in" {
    name = "vnc-in"
    description = "Allow vnc connections"
    vpc_id = aws_vpc.vpc.id

  ingress {
    from_port = 5900
    to_port = 5910
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "sg-vnc"
    }
}

resource "aws_security_group" "sg-all-out" {
    name = "all-out"
    description = "Allow all outgoing traffic"
    vpc_id = aws_vpc.vpc.id

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "all-out"
    }
}


##EC2s
##SSH key
resource "aws_key_pair" "ssh-key" {
  key_name = "ssh-key-${local.suffix}"
  public_key = file("${path.module}/${var.ssh-keyfile}")
}

#AMI
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

#Baremetal host
resource "aws_instance" "baremetal" {
  ami = data.aws_ami.rhel8.id
  instance_type = var.instance_type
  subnet_id = aws_subnet.subnet_pub.id
  vpc_security_group_ids = [aws_security_group.sg-ssh-in.id,aws_security_group.sg-web-in.id,aws_security_group.sg-vnc-in.id,aws_security_group.sg-all-out.id,aws_security_group.sg-api-in.id]
  key_name= aws_key_pair.ssh-key.key_name

  root_block_device {
      volume_size = 40
      delete_on_termination = true
  }

  ebs_block_device {
    volume_size = 1000
    delete_on_termination = true
    device_name = "/dev/sdb"
  }

  tags = {
        Name = "baremetal-${local.suffix}"
  }
}
