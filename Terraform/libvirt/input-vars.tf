#VARIABLES
variable "rhel8_image_location" {
 description = "Path to the RHEL 8 qcow2 image to be used as base image for VMs"
  type = string
  default = "rhel8.qcow2"
}

variable "provision_resources" {
  description = "Ammount of CPU and memory resources assigned to the provisioning VM"
  type = object({
    memory = string
    vcpu = number
  })
  default = {
    memory = "24576"
    vcpu = 4
  }
}

variable "support_resources" {
  description = "Ammount of CPU and memory resources assigned to the support VM"
  type = object({
    memory = string
    vcpu = number
  })
  default = {
    memory = "24576"
    vcpu = 4
  }
}

variable "number_of_workers" {
  description = "How many worker VMs to create"
  type = number
  default = 3
}

variable "chucky_net_addr" {
  description = "Network address for the routable chucky network"
  type = string
  default = "192.168.30.0/24"
}

variable "provision_net_addr" {
  description = "Network address for the private provision network"
  type = string
  default = "192.168.14.0/24"
}

variable "support_net_config_nameserver" {
  description = "DNS server IP for the support VM's network configuration"
  type = string
  default = "8.8.8.8"
}


locals {
  #Last octect of the IP address for the network interface connected to the provisioning network in the provisioning VM
  provision_ironiq_addr = replace(var.provision_net_addr,".0/",".14/")

  support_net_config_address = replace(var.chucky_net_addr,".0/",".3/")
  support_net_config_gateway = replace(var.chucky_net_addr,".0/24",".1")
}
