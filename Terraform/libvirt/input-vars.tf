#VARIABLES
variable "rhel8_image_location" {
 description = "Path to the RHEL 8 qcow2 image to be used as base image for VMs"
  type = string
  default = "rhel8.qcow2"
}
