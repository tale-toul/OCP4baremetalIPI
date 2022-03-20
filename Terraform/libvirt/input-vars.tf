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

variable "support_net_config" {
  description = "Network configuration parameters for the support VM"
  type = object({
    address = string 
    nameserver = string
    gateway = string
  })
  default = {
    address = "192.168.30.3/24"
    nameserver = "8.8.8.8"
    gateway = "192.168.30.1"
  }
}

variable "provision_ironiq_addr" {
  description = "IP address for the network interface connected to the provisioning network in the provisioning VM"
  type = string
  default = "192.168.14.14"
}
