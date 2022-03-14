#VARIABLES
variable "rhel8_image_location" {
 description = "Path to the RHEL 8 qcow2 image to be used as base image for VMs"
  type = string
  default = "rhel8.qcow2"
}

variable "number_of_workers" {
  description = "How many worker VMs to create"
  type = number
  default = 3
}
