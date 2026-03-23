module "routers" {
  for_each = local.router_runtime

  source = "../../module/nvl-router"

  depends_on = [terraform_data.validate_router_inputs]

  vi = module.vi

  name                = each.value.name
  ip                  = try(each.value.networks.wan.ip, null)
  gateway             = each.value.networks.wan.gateway
  nameservers         = each.value.networks.wan.nameservers
  subnet_mask         = each.value.networks.wan.subnet_mask
  vm_password         = var.vm_admin_password
  ssh_authorized_keys = local.ssh_authorized_keys
  wan_network_name    = each.value.networks.wan.network_name
  network_name        = each.value.networks.lan.network_name

  ubuntu_ovf_url = each.value.install_source.type == "http_ovf" ? each.value.install_source.url : null
  local_ovf_path = each.value.install_source.type == "local_ovf" ? each.value.install_source.path : null

  nested_network = {
    domain_name        = each.value.networks.lan.domain_name
    network            = each.value.networks.lan.network
    vlan_starts_with   = each.value.networks.lan.vlan_starts_with
    vlan_network_count = each.value.networks.lan.vlan_network_count
    mtu                = each.value.networks.lan.mtu
  }
}
