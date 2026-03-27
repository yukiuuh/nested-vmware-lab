module "storages" {
  for_each = local.storage_runtime

  source = "../../module/nvl-storage"

  depends_on = [
    terraform_data.validate_storage_inputs,
  ]

  vi = module.vi

  name                = each.value.name
  ip                  = each.value.service.ip
  gateway             = each.value.network.gateway
  nameservers         = each.value.network.nameservers
  domain_name         = each.value.network.domain_name
  subnet_mask         = each.value.network.subnet_mask
  vm_password         = var.vm_admin_password
  ssh_authorized_keys = local.ssh_authorized_keys
  network_name        = each.value.network.network_name

  ubuntu_ovf_url = each.value.install_source.type == "http_ovf" ? each.value.install_source.url : null
  local_ovf_path = each.value.install_source.type == "local_ovf" ? each.value.install_source.path : null

  num_cpus             = each.value.shape.num_cpus
  mem_gb               = each.value.shape.mem_gb
  storage1_ip          = each.value.service.storage1_ip
  storage2_ip          = each.value.service.storage2_ip
  storage1_vlan        = each.value.service.storage1_vlan
  storage2_vlan        = each.value.service.storage2_vlan
  storage_mtu          = each.value.service.storage_mtu
  storage_subnet_mask  = each.value.service.storage_subnet_mask
  storage_disk_size_gb = each.value.service.storage_disk_size_gb
  luns                 = each.value.service.luns
  zfs_compression      = each.value.service.zfs_compression
  zfs_nfs_dedup        = each.value.service.zfs_nfs_dedup
}
