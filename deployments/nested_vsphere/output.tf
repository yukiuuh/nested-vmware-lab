output "esxi_hosts" {
  value = values(tomap(module.esxi_cluster.esxi_hosts))
}

output "vcsa_standalone" {
  value = module.vcsa_standalone
}