output "esxi_hosts" {
  value = values(tomap(module.esxi_cluster.esxi_hosts))
}
