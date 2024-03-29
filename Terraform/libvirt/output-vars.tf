#OUTPUT
output "chucky_net_addr" {
  value       = var.chucky_net_addr
  description = "Network address for the routable chucky network"
}

output "worker_provision_mac_base" {
  value       = var.worker_provision_mac_base
  description = "MAC address common part for the worker NICs in the provisioning network"
}

output "worker_chucky_mac_base" {
  value       = var.worker_chucky_mac_base
  description = "MAC address common part for the worker NICs in the chucky network"
}

output "provision_net_addr" {
  value       = var.provision_net_addr
  description = "Network address for the private provision network"
}

output "provision_mac" {
  value       = var.provision_mac
  description = "MAC address for provision VM NIC"
}

output "master_provision_mac_base" {
  value       = var.master_provision_mac_base
  description = "MAC address common part for the master NICs in the provisioning network"
}

output "master_chucky_mac_base" {
  value       = var.master_chucky_mac_base
  description = "MAC address common part for the master NICs in the chucky network"
}

output "support_host_ip" {  
 value       = local.support_host_ip
 description = "The support host IP address in the routable network"
}

output "provision_host_ip" {
  value      = local.provision_host_ip
  description = "The provision host IP address in the routable network"
}

output "api_vip" {
  value      = local.api_vip
  description = "IP address for the OCP API VIP, in routable chucky network"
}

output "ingress_vip" {
  value      = local.ingress_vip
  description = "IP address for the OCP ingress VIP, in routable chucky network"
}

output "chucky_gateway" {
  value       = local.chucky_gateway
  description = "Gateway IP for the routable chucky network"
}

output "provisioning_dhcp_start" {
  value       = local.provisioning_dhcp_start
  description = "Start of the provisioning networkk DHCP Range"
}

output "provisioning_dhcp_end" {
  value       = local.provisioning_dhcp_end
  description = "End of the provisioning networkk DHCP Range"
}

output "master_names" {
  value     = libvirt_domain.master_domains[*].name
  description = "List of master node names"
}

output "worker_names" {
  value     = libvirt_domain.worker_domains[*].name
  description = "List of worker node names"
}

output "number_of_workers" {
  value     = var.number_of_workers
  description = "How many worker nodes have been created"
}

output "dns_zone" {
  value     = var.dns_zone
  description = "DNS base zone for the Openshift cluster"
}

output "cluster_name" {
  value = var.cluster_name
  description = "Cluster name that is part of the DNS domain"
}

output "ocp_version" {
  value = var.ocp_version
  description = "Openshift version number to be deployed"
}

output "architecture" {
  value = var.architecture
  description = "Architecture style: redfish or VBMC"
}

output "bonding_nic" {
  value = var.bonding_nic
  description = "Select whether to use a network bonding interface in master and workers (true), or a single NIC (false)"
}

output "ocp_minor_version" {
  value = local.ocp_minor_version
  description = "OCP cluster minor version"
}
