#OUTPUT
output "chucky_net_addr" {
  value       = var.chucky_net_addr
  description = "Network address for the routable chucky network"
}

output "provision_net_addr" {
  value       = var.provision_net_addr
  description = "Network address for the private provision network"
}

output "support_host_ip" {  
 value       = local.support_net_config_address
 description = "The support host IP address"
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
