output "deployment_model" {
  value = {
    name_prefix         = var.name_prefix
    deployment_name     = local.deployment_name_prefix
    provider_config     = local.provider
    install_sources     = local.install_sources
    routers             = local.routers
    esxi_groups         = local.esxi_groups
    ssh_authorized_keys = local.ssh_authorized_keys
    vcenters            = local.vcenters
    services            = local.services
  }
}

output "deployment_name_prefix" {
  value = local.deployment_name_prefix
}

output "routers" {
  value = local.router_outputs
}

output "esxi_groups" {
  value = local.esxi_group_outputs
}

output "ansible_inventory_seed" {
  sensitive = true
  value = {
    credentials = {
      vm_admin_password = var.vm_admin_password
      vsphere = {
        server     = local.provider.server
        user       = local.provider.user
        password   = local.provider.password
        datacenter = local.provider.datacenter
      }
    }
    routers     = local.router_outputs
    esxi_groups = local.esxi_group_outputs
    vcenters    = local.vcenters
    services    = local.services
  }
}
