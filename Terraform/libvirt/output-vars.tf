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
