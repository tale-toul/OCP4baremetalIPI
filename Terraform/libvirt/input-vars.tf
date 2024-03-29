#VARIABLES
variable "rhel8_image_location" {
 description = "Path and name to the RHEL 8 qcow2 image to be used as base image for VMs"
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

variable "master_resources" {
  description = "Ammount of CPU and memory resources assigned to the master VMs"
  type = object({
    memory = string
    vcpu = number
  })
  default = {
    memory = "16384"
    vcpu = 4
  }
}

variable "worker_resources" {
  description = "Ammount of CPU and memory resources assigned to the worker VMs"
  type = object({
    memory = string
    vcpu = number
  })
  default = {
    memory = "16384"
    vcpu = 4
  }
}

variable "number_of_workers" {
  description = "How many worker VMs to create"
  type = number
  default = 3

  validation {
    condition = var.number_of_workers > 0 && var.number_of_workers <= 128
    error_message = "The number of workers that can be created with terraform must be between 1 and 128."
  }
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

variable "dns_zone" {
  description = "Internal DNS base zone for the Openshift cluster"
  type = string
  default = "tale.net"
}

variable "cluster_name" {
  description = "Cluster name which is part of the internal DNS domain"
  type = string
  default = "ocp4"
}

variable "ocp_version" {
  description = "Openshift version number to be deployed"
  type = string
  default = "4.9.5"
}

variable "architecture" {
  description = "Architecture style: redfish or VBMC"
  type = string
  default = "vbmc"

  validation {
    condition = var.architecture == "redfish" || var.architecture == "vbmc"
    error_message = "The architecture style can only be redfish or vbmc."
  }
}

variable "bonding_nic" {
  description = "Select whether to use a network bonding interface in master and workers (true), or a single NIC (false)"
  type = bool
  default = "false"
}

#MAC ADDRESSES
#The letters in the MACs should be in lowercase
variable "provision_mac" {
  description = "MAC address for provision VM NIC in the routable (chucky) network"
  type = string
  default = "52:54:00:9d:41:3c"
}

variable "master_provision_mac_base" {
  description = "MAC address common part for the master NICs in the provisioning network"
  type = string
  default = "52:54:00:74:dc:a"
}

variable "master_chucky_mac_base" {
  description = "MAC address common part for the master NICs in the chucky network"
  type = string
  default = "52:54:00:a9:6d:7"
}

variable "worker_provision_mac_base" {
  description = "MAC address common part for the worker NICs in the provisioning network"
  type = string
  default = "52:54:00:74:dc:"
}

variable "worker_chucky_mac_base" {
  description = "MAC address common part for the worker NICs in the chucky network"
  type = string
  default = "52:54:00:a9:6d:"
}

locals {

  #IP address for the network interface connected to the provisioning network in the provisioning VM
  provision_ironiq_addr = replace(var.provision_net_addr,".0/",".14/")

  #IP address for the support VM in the chucky network
  support_host_ip =            replace(var.chucky_net_addr,".0/24",".3")

  #IP address for the provision VM in the chucky network
  provision_host_ip =          replace(var.chucky_net_addr,".0/24",".10")

  #Gateway IP for the routable chucky network
  chucky_gateway = replace(var.chucky_net_addr,".0/24",".1")

  #IP address for the OCP API VIP, in routable chucky network
  api_vip = replace(var.chucky_net_addr,".0/24",".100")

  #IP address for the OCP ingress VIP, in routable chucky network
  ingress_vip = replace(var.chucky_net_addr,".0/24",".110")

  #Start of the provisioning networkk DHCP Range
  provisioning_dhcp_start = replace(var.provision_net_addr,".0/24",".20")

  #End of the provisioning networkk DHCP Range
  provisioning_dhcp_end = replace(var.provision_net_addr,".0/24",".100")

  #OCP minor version
  #Extract the minor version from the string 4.(minor).z with a regular expression regex(...).  This returns a list
  #Get the single element from the list and return it as a string. one(...)
  #Translate the minor version string to an integer in base 10. parseint(...)
  ocp_minor_version = parseint(one(regex("4\\.([0-9]+)\\.",var.ocp_version)),10)
}
