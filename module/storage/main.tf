

module "management_address" {
  source     = "../common/netmask2prefix"
  ip_address = var.ip
  netmask    = var.subnet_mask
}
module "storage_address" {
  source     = "../common/netmask2prefix"
  ip_address = var.storage1_ip
  netmask    = var.storage_subnet_mask
}
locals {
  storage_hostname  = "storage"
  storage_user      = "labadmin"
  storage_nfs_share = "/pool01/nfs"
  lun_name_list     = [for i in range(var.lun_count) : "vol${i}"]
  storage_userdata = templatefile("${path.module}/templates/userdata.tftpl",
    {
      ssh_authorized_keys = var.ssh_authorized_keys
      password            = var.vm_password
      user                = local.storage_user
      ip_address          = var.ip
      prefix              = module.management_address.prefix_length
      storage_prefix      = module.storage_address.prefix_length
      gateway             = var.gateway
      nameservers         = var.nameservers
      domain              = var.domain_name
      hostname            = local.storage_hostname
      storage_mtu         = var.storage_mtu
      storage1_ip         = var.storage1_ip
      storage2_ip         = var.storage2_ip
      storage1_vlan       = var.storage1_vlan
      storage2_vlan       = var.storage2_vlan
      lun_size_gb         = var.lun_size_gb
      lun_name_list       = local.lun_name_list
      zfs_compression     = var.zfs_compression
      zfs_nfs_dedup       = var.zfs_nfs_dedup
    }
  )
}


module "storage" {
  source             = "../common/ubuntu"
  vi                 = var.vi
  name               = var.name
  remote_ovf_url     = var.ubuntu_ovf_url
  userdata           = local.storage_userdata
  network_interfaces = [var.network_name, var.network_name, var.network_name]
  num_cpus           = 4
  mem_gb             = 4
  disks = [
    {
      "label"       = "disk0"
      "size_gb"     = 16
      "unit_number" = 0
    },
    {
      "label"       = "disk1"
      "size_gb"     = var.storage_disk_size_gb
      "unit_number" = 1
    }
  ]
}
