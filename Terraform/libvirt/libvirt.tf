terraform {
  required_providers {
    libvirt = {
      source = "dmacvicar/libvirt"
      version = "0.6.14"
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
  uri = "qemu+ssh://ec2-user@${data.terraform_remote_state.ec2_instance.outputs.baremetal_public_ip}/system?keyfile=../${data.terraform_remote_state.ec2_instance.outputs.ssh_certificate}&known_hosts_verify=ignore"
}

#Networks
resource "libvirt_network" "chucky" {
  name = "chucky"
  mode = "nat"
  addresses = [var.chucky_net_addr]
  bridge = "chucky"
  autostart = true

  dhcp {
    enabled = false
  }
}

resource "libvirt_network" "provision" {
  count = var.architecture == "vbmc" ? 1 : 0
  name = "provision"
  mode = "none"
  addresses = [var.provision_net_addr]
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

#PROVISION VM 
resource "libvirt_volume" "provision_volume" {
  name = "provision.qcow2"
  base_volume_id = libvirt_volume.rhel_volume.id
  #120GB
  size = 128849018880
}

resource "libvirt_cloudinit_disk" "provision_cloudinit" {
  name = "provision.iso"
  user_data = templatefile("${path.module}/provision_cloud_init.tmpl", { auth_key = file("${path.module}/../${data.terraform_remote_state.ec2_instance.outputs.ssh_certificate}") })
  network_config = templatefile("${path.module}/provision_network_config.tmpl", { ironiq_addr = local.provision_ironiq_addr, architecture = var.architecture, provision_host_ip = "${local.provision_host_ip}/24", gateway = local.chucky_gateway, nameserver = local.support_host_ip })
}

#Provisioning VM
resource "libvirt_domain" "provision_domain" {
  name = "provision"
  running = true
  autostart = false

  memory = var.provision_resources.memory
  vcpu   = var.provision_resources.vcpu
  cloudinit = libvirt_cloudinit_disk.provision_cloudinit.id

  disk {
    volume_id = libvirt_volume.provision_volume.id
  }

  cpu {
    mode = "host-passthrough"
  }

  dynamic "network_interface" {
    for_each = toset(libvirt_network.provision[*].id)
    content {
      network_id = network_interface.key
    }
  }

  network_interface {
    network_id = libvirt_network.chucky.id
    mac        = var.provision_mac
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
  #120GB
  size = 128849018880
}

#Master VMs
resource "libvirt_domain" "master_domains" {
  count = 3
  name = "bmipi-master${count.index}"
  running = false
  autostart = false

  memory = var.master_resources.memory
  vcpu   = var.master_resources.vcpu

  disk {
    volume_id = libvirt_volume.master_volumes[count.index].id
  }

  dynamic "network_interface" {
    for_each = toset(libvirt_network.provision[*].id)
    content {
      network_id = network_interface.key
      mac        = "${var.master_provision_mac_base}${count.index}"
    }
  }

  cpu {
    mode = "host-passthrough"
  }

#Main NIC connected to the provisioning network
  network_interface {
    network_id = libvirt_network.chucky.id
    mac        = "${var.master_chucky_mac_base}${count.index}"
  }

#The MAC address is shifted by 3 which is the number of masters
#The second NIC is created only if requested by setting bonding_nic to true and the OCP version is 4.10+
  dynamic "network_interface" {
    for_each = var.bonding_nic == true && local.ocp_minor_version >= 10 ? [1] : []
    content {
      network_id = libvirt_network.chucky.id
      mac        = format("${var.master_chucky_mac_base}%x",count.index + 3)
    }
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
  count = var.number_of_workers
  name = "worker${count.index}.qcow2"
  pool = "default"
  format = "qcow2"
  #120GB
  size = 128849018880
}

#Worker VMs
resource "libvirt_domain" "worker_domains" {
  count = var.number_of_workers
  name = "bmipi-worker${count.index}"
  running = false
  autostart = false

  memory = var.worker_resources.memory
  vcpu   = var.worker_resources.vcpu

  disk {
    volume_id = libvirt_volume.worker_volumes[count.index].id
  }

  cpu {
    mode = "host-passthrough"
  }

  dynamic "network_interface" {
    for_each = toset(libvirt_network.provision[*].id)
    content {
      network_id = network_interface.key
      mac        = format("${var.worker_provision_mac_base}%02x",count.index)
    }
  }

  network_interface {
    network_id = libvirt_network.chucky.id
    mac        = format("${var.worker_chucky_mac_base}%02x",count.index)
  }

#The MAC address is shifted by the number of workers, which is contained in the number_of_workers variable
#The second NIC is created only if requested by setting bonding_nic to true and the OCP version is 4.10+
  dynamic "network_interface" {
    for_each = var.bonding_nic == true && local.ocp_minor_version >= 10 ? [1] : []
    content {
      network_id = libvirt_network.chucky.id
      mac        = format("${var.worker_chucky_mac_base}%02x",count.index + var.number_of_workers)
    }
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

#Support VM
#Support volume
resource "libvirt_volume" "support_volume" {
  name = "support.qcow2"
  base_volume_id = libvirt_volume.rhel_volume.id
  #50GB
  size = 53687091200
}

resource "libvirt_cloudinit_disk" "support_cloudinit" {
  name = "support.iso"
  user_data = templatefile("${path.module}/support_cloud_init.tmpl", { auth_key = file("${path.module}/../${data.terraform_remote_state.ec2_instance.outputs.ssh_certificate}") })
  network_config = templatefile("${path.module}/support_network_config.tmpl", { address = "${local.support_host_ip}/24", nameserver = var.support_net_config_nameserver, gateway = local.chucky_gateway })
}

#Support VM
resource "libvirt_domain" "support_domain" {
  name = "support"
  running = true
  autostart = false

  memory = var.support_resources.memory
  vcpu   = var.support_resources.vcpu
  cloudinit = libvirt_cloudinit_disk.support_cloudinit.id

  disk {
    volume_id = libvirt_volume.support_volume.id
  }

  cpu {
    mode = "host-passthrough"
  }

  network_interface {
    network_id = libvirt_network.chucky.id
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
