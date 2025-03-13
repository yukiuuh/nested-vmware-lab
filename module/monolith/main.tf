

module "wan_address" {
  source     = "../common/netmask2prefix"
  ip_address = var.ip
  netmask    = var.subnet_mask
}
locals {
  nested_network_address = "${var.nested_network.network}/16"
  monolith_hostname      = "monolith"
  monolith_user          = "labadmin"
  monolith_nfs_share     = "/pool01/nfs"
  monolith_userdata = templatefile("../../templates/monolith/userdata.tftpl",
    {
      ssh_authorized_keys = var.ssh_authorized_keys
      password            = var.vm_password
      user                = local.monolith_user
      ip_address          = var.ip
      subnet_mask         = module.management_address.prefix_length
      gateway             = var.gateway
      nameservers         = var.nameservers
      domain              = var.nested_network.domain_name
      hostname            = local.monolith_hostname
      vlan_mtu            = var.nested_network.mtu
    }
  )
  management_network_address = cidrsubnet(local.nested_network_address, 8, 0)
  vlan_network_addresses = {
    for i in range(var.nested_network.vlan_network_count) : i => {
      "vlan"    = var.nested_network.vlan_starts_with + i
      "network" = cidrsubnet(local.nested_network_address, 8, i + 1)
    }
  }
}


module "monolith" {
  source             = "../common/ubuntu"
  vi                 = module.vi
  name               = var.name
  remote_ovf_url     = var.remote_ovf_url
  userdata           = local.monolith_userdata
  network_interfaces = [var.management_network, var.lab_network]
  num_cpus           = 4
  mem_gb             = 4
  disks = [
    {
      "label"       = "disk0"
      "size_gb"     = 30
      "unit_number" = 0
    },
    {
      "label"       = "disk1"
      "size_gb"     = var.monolith_storage_size_gb
      "unit_number" = 1
    }
  ]
}
