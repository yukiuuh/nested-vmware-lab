output "name" {
  value = var.name
}

output "wan_ip" {
  value = var.ip != null && var.ip != "" ? var.ip : module.router.vm_info.default_ip_address
}

output "management_network" {
  value = local.management_network_address
}

output "vlan_networks" {
  value = [for vlan_network in local.vlan_networks : {
    vlan    = vlan_network.vlan
    address = vlan_network.address
  }]
}