locals {
  node_count    = var.single_node ? 1 : 3
  cidr_prefix   = join(".", slice(split(".", var.starting_ip), 0, 3))
  starting_host = tonumber(element(split(".", var.starting_ip), 3))
  nodes = {
    for i in range(local.node_count) : i => ({
      hostname = format("%s%02d.%s", var.hostname_prefix, i + 1, var.domain_name)
      ip       = format("%s.%d", local.cidr_prefix, local.starting_host + i)
      name     = "${var.name_prefix}-${format("%s%02d", var.hostname_prefix, i + 1)}"
      password = var.vm_password
      source   = var.remote_ovf_url
    })
  }
}

module "vrli" {
  source            = "../common/vrli"
  for_each          = local.nodes
  vi                = var.vi
  name              = each.value.name
  netmask           = var.subnet_mask
  vm_password       = var.vm_password
  domain_name       = var.domain_name
  dns_server        = var.nameservers[0]
  ip_address        = each.value.ip
  authorized_key    = length(var.ssh_authorized_keys) > 0 ? var.ssh_authorized_keys[0] : ""
  remote_ovf_url    = var.remote_ovf_url
  fqdn              = each.value.hostname
  gateway           = var.gateway
  deployment_option = var.deployment_option
  network_name      = var.network_name
}
