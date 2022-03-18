terraform {
  required_providers {
    libvirt = {
      source = "dmacvicar/libvirt"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

#Default storage pool
resource "libvirt_pool" "pool_default" {
  name = "default"
  type = "dir"
  path = "/var/lib/libvirt/images"
}
