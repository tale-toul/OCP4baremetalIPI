#OUTPUT
output "support_host_ip" {  
 value       = var.support_net_config.address
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
