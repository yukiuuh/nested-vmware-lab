provider "vsphere" {
  allow_unverified_ssl = true
  user                 = var.vsphere_user
  password             = var.vsphere_password
  vsphere_server       = var.vsphere_server
}

module "vi" {
  source           = "../../module/common/vi"
  datacenter       = var.datacenter
  resource_pool    = var.resource_pool
  compute_host     = var.compute_host
  datastore        = var.datastore
  networks         = [var.network_name]
  vsphere_password = var.vsphere_password
  vsphere_server   = var.vsphere_server
  vsphere_user     = var.vsphere_user
}

resource "random_id" "uuid" {
  byte_length = 4
}

locals {
  name_prefix = "${var.name_prefix}-${random_id.uuid.hex}"
}

module "esxi_cluster" {
  source                      = "../../module/nested_esxi_cluster"
  ks_server_ip                = var.ks_server_ip
  create_ks_server            = true
  storage_vmknics             = var.storage_vmknics
  ks_server_password          = var.vm_password
  nested_esxi_count           = var.nested_esxi_count
  nameservers                 = var.nameservers
  nfs_hosts                   = var.nfs_hosts
  iscsi_targets               = var.iscsi_targets
  vi                          = module.vi
  name_prefix                 = local.name_prefix
  gateway                     = var.gateway
  network_name                = var.network_name
  esxi_iso_datastore          = var.esxi_iso_datastore
  esxi_iso_path               = var.esxi_iso_path
  subnet_mask                 = var.subnet_mask
  vm_password                 = var.vm_password
  domain_name                 = var.domain_name
  ntp                         = var.ntp
  vlan                        = var.vlan
  nested_esxi_starting_ip     = var.nested_esxi_starting_ip
  nested_esxi_hostname_prefix = var.nested_esxi_hostname_prefix
  nested_esxi_shape           = var.nested_esxi_shape
  provision_datastores        = var.provision_datastores
}