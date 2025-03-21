module "ks_server_address" {
  source     = "../common/netmask2prefix"
  ip_address = var.ks_server_ip != null ? var.ks_server_ip : "0.0.0.0"
  netmask    = var.subnet_mask
}

locals {
  vm_password = var.ks_server_password
  userdata = templatefile("${path.module}/templates/userdata.tftpl",
    {
      password = local.vm_password
  })
  metadata = templatefile("${path.module}/templates/metadata.tftpl",
    {
      ip_address    = var.ks_server_ip != null ? var.ks_server_ip : ""
      subnet_prefix = module.ks_server_address.prefix_length
  })
}

module "kickstarter_photon" {
  source             = "../common/photon"
  vi                 = var.vi
  name               = var.name
  userdata           = local.userdata
  metadata           = local.metadata
  network_interfaces = var.network_interfaces
  remote_ovf_url     = var.remote_ovf_url
  num_cpus           = 2
  mem_gb             = 1
}
