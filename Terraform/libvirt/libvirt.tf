terraform {
  required_providers {
    libvirt = {
      source = "dmacvicar/libvirt"
    }
  }
}
data "terraform_remote_state" "ec2_instance" {
  backend = "local"

  config = {
    path = "../terraform.tfstate"
  }
}

provider "libvirt" {
  uri = "qemu+ssh://ec2-user@${data.terraform_remote_state.ec2_instance.outputs.baremetal_public_ip}/system?keyfile=../${data.terraform_remote_state.ec2_instance.outputs.ssh_certificate}"
}

#Default storage pool
resource "libvirt_pool" "pool_default" {
  name = "default"
  type = "dir"
  path = "/var/lib/libvirt/images"
}

#Networks
resource "libvirt_network" "chucky" {
  name = "chucky"
  mode = "nat"
  addresses = ["192.168.30.0/24"]
  bridge = "chucky"
  autostart = true

  dhcp {
    enabled = false
  }
}

resource "libvirt_network" "provision" {
  name = "provision"
  mode = "none"
  addresses = ["192.168.14.0/24"]
  bridge = "provision"
  autostart = true

  dhcp {
    enabled = false
  }
}

#RHEL base image
resource "libvirt_volume" "rhel_volume" {
  name = "rhel8_base.qcow2"
  source = "${var.rhel8_image_location}"
  format = "qcow2"
}

resource "libvirt_volume" "provision_volume" {
  name = "provision.qcow2"
  base_volume_id = libvirt_volume.rhel_volume.id
  #120GB
  size = 128849018880
}

data "template_file" "host_config" {
  template = file("${path.module}/cloud_init.cfg")

  vars = {
    auth_key = file("${path.module}/../${data.terraform_remote_state.ec2_instance.outputs.ssh_certificate}")
  }
}

resource "libvirt_cloudinit_disk" "provision_cloudinit" {
  name = "provision.iso"
  pool = libvirt_pool.pool_default.name
  user_data = data.template_file.host_config.rendered
}

#Provisioning VM
resource "libvirt_domain" "provision_domain" {
  name = "provision"
  running = true
  autostart = false

  memory = "24096"
  vcpu   = 4
  cloudinit = libvirt_cloudinit_disk.provision_cloudinit.id

  disk {
    volume_id = libvirt_volume.provision_volume.id
  }

  cpu {
    mode = "host-passthrough"
  }

  network_interface {
    network_id = libvirt_network.provision.id
  }
  network_interface {
    network_id = libvirt_network.chucky.id
    mac        = "52:54:00:9d:41:3c"
  }

  boot_device {
    dev = ["hd","network"]
  }

  graphics {
    type = "vnc"
    listen_type = "address"
    listen_address = "0.0.0.0"
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "virtio"
  }
}

#MASTER NODES
#Master volumes
resource "libvirt_volume" "master_volumes" {
  count = 3
  name = "master${count.index}.qcow2"
  pool = "default"
  format = "qcow2"
  #80GB
  size = 85899345920
}

#Master VMs
resource "libvirt_domain" "master_domains" {
  count = 3
  name = "bmipi-master${count.index}"
  running = false
  autostart = false

  memory = "16384"
  vcpu   = 4

  disk {
    volume_id = libvirt_volume.master_volumes[count.index].id
  }

  network_interface {
    network_id = libvirt_network.provision.id
    mac        = "52:54:00:74:dc:a${count.index}"
  }
  network_interface {
    network_id = libvirt_network.chucky.id
    mac        = "52:54:00:a9:6d:7${count.index} "
  }

  boot_device {
    dev = ["hd","network"]
  }

  graphics {
    type = "vnc"
    listen_type = "address"
    listen_address = "0.0.0.0"
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "virtio"
  }
}

#WORKER NODES
#Worker volumes
resource "libvirt_volume" "worker_volumes" {
  count = 3
  name = "worker${count.index}.qcow2"
  pool = "default"
  format = "qcow2"
  #80GB
  size = 85899345920
}

#Worker VMs
resource "libvirt_domain" "worker_domains" {
  count = 3
  name = "bmipi-worker${count.index}"
  running = false
  autostart = false

  memory = "16384"
  vcpu   = 4

  disk {
    volume_id = libvirt_volume.worker_volumes[count.index].id
  }

  network_interface {
    network_id = libvirt_network.provision.id
    mac        = "52:54:00:74:dc:d${count.index}"
  }
  network_interface {
    network_id = libvirt_network.chucky.id
    mac        = "52:54:00:a9:6d:9${count.index} "
  }

  boot_device {
    dev = ["hd","network"]
  }

  graphics {
    type = "vnc"
    listen_type = "address"
    listen_address = "0.0.0.0"
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "virtio"
  }
}
