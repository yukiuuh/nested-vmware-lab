output "esxi_hosts" {
  value = values(tomap(module.esxi_cluster.esxi_hosts))
}

output "vcsa" {
  value = var.nested_vcsa != null ? (local.is_vcsa_self_managed ? module.vsphere_kickstarter[0].vcsa_info : module.vcsa_standalone[0]) : null
}

output "storage" {
  value = var.storage != null ? module.storage[0] : null
}

output "router" {
  value = var.external_network != null ? module.router[0] : null
}

output "tkg-cli" {
  value = var.create_tkg_client ? module.tkg_cli[0] : null
}

output "nsx" {
  value = var.nsx != null ? {
    managers = module.vsphere_provisioner[0].nsx_managers
    edges    = module.vsphere_provisioner[0].nsx_edges
  } : null
}
output "vcf_installer" {
  value = var.vcf_installer != null ? module.vcf_installer[0] : null
}
output "cloud_builder" {
  value = var.cloud_builder != null ? module.cloud_builder[0] : null
}
output "avi" {
  value = var.avi != null ? {
    controllers = module.vsphere_provisioner[0].avi_controllers
  } : null
}
