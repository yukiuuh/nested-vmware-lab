

module "wan_address" {
  source     = "../common/netmask2prefix"
  ip_address = var.ip
  netmask    = var.subnet_mask
}


module "management_address" {
  source     = "../common/netmask2prefix"
  ip_address = var.ip
  netmask    = "255.255.255.0"
}
locals {
  nested_network_address = "${var.nested_network.network}/16"
  router_hostname        = "router"
  router_user            = "labadmin"

  management_network_address = cidrsubnet(local.nested_network_address, 8, 0)
  vlan_networks = {
    for i in range(var.nested_network.vlan_network_count) : i => {
      "vlan"    = var.nested_network.vlan_starts_with + i
      "address" = cidrsubnet(local.nested_network_address, 8, i + 1)
    }
  }
  router_userdata = templatefile("${path.module}/templates/userdata.tftpl",
    {
      ssh_authorized_keys        = var.ssh_authorized_keys
      password                   = var.vm_password
      user                       = local.router_user
      vlan_networks              = local.vlan_networks
      management_network_address = local.management_network_address
      ip_address                 = var.ip
      subnet_mask                = module.management_address.prefix_length
      gateway                    = var.gateway
      nameservers                = var.nameservers
      domain                     = var.nested_network.domain_name
      hostname                   = local.router_hostname
      vlan_mtu                   = var.nested_network.mtu
      hosts_base64 = base64encode(templatefile("${path.module}/templates/hosts.tftpl",
        {
          management_network_address = local.management_network_address
          domain                     = var.nested_network.domain_name
          hostname                   = local.router_hostname
        }
      ))
    }
  )
}


module "router" {
  source             = "../common/ubuntu"
  vi                 = var.vi
  name               = var.name
  remote_ovf_url     = var.ubuntu_ovf_url
  userdata           = local.router_userdata
  network_interfaces = [var.wan_network_name, var.network_name]
  num_cpus           = 2
  mem_gb             = 1
  disks = [
    {
      "label"       = "disk0"
      "size_gb"     = 10
      "unit_number" = 0
    }
  ]
}
