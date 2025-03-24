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
  networks         = var.external_network != null ? [var.external_network.name, var.network_name] : [var.network_name]
  vsphere_password = var.vsphere_password
  vsphere_server   = var.vsphere_server
  vsphere_user     = var.vsphere_user
}

resource "random_id" "uuid" {
  byte_length = 4
}

locals {
  name_prefix          = "${var.name_prefix}-${random_id.uuid.hex}"
  is_vcsa_self_managed = var.nested_vcsa != null ? var.nested_vcsa.self_managed : false
  router_user          = "labadmin"
}

resource "tls_private_key" "ed25519" {
  algorithm = "ED25519"
}

module "router" {
  count               = var.external_network != null ? 1 : 0
  source              = "../../module/router"
  vi                  = module.vi
  name                = "${local.name_prefix}-router"
  network_name        = var.network_name
  gateway             = var.external_network.gateway
  nameservers         = var.external_network.nameservers
  subnet_mask         = var.external_network.subnet_mask
  vm_password         = var.vm_password
  ubuntu_ovf_url      = var.ubuntu_ovf_url
  ip                  = var.external_network.ip
  wan_network_name    = var.external_network.name
  ssh_authorized_keys = concat([tls_private_key.ed25519.public_key_openssh], var.ssh_authorized_keys)
  nested_network      = var.lab_network
}

module "storage" {
  count                = var.storage != null ? 1 : 0
  source               = "../../module/storage"
  depends_on           = [module.router]
  vi                   = module.vi
  name                 = "${local.name_prefix}-storage"
  ip                   = var.storage.ip
  gateway              = var.gateway
  nameservers          = var.nameservers
  domain_name          = var.domain_name
  subnet_mask          = var.subnet_mask
  ssh_authorized_keys  = var.ssh_authorized_keys
  vm_password          = var.vm_password
  storage1_ip          = var.storage.storage1_ip
  storage2_ip          = var.storage.storage2_ip
  storage1_vlan        = var.storage.storage1_vlan
  storage2_vlan        = var.storage.storage2_vlan
  storage_mtu          = var.storage.mtu
  storage_subnet_mask  = var.storage.subnet_mask
  storage_disk_size_gb = var.storage.disk_size_gb
  lun_size_gb          = var.storage.lun_size_gb
  lun_count            = var.storage.lun_count
  network_name         = var.network_name
  ubuntu_ovf_url       = var.ubuntu_ovf_url
}

locals {
  vcsa_vmname = "${local.name_prefix}-${var.nested_vcsa.hostname}"
}

module "vsphere_kickstarter" {
  count                  = var.nested_vcsa != null ? 1 : 0
  source                 = "../../module/vsphere_kickstarter"
  depends_on             = [module.router]
  network_interfaces     = [var.network_name]
  vsphere_kickstarter_ip = var.ks_server_ip
  gateway                = var.gateway
  name                   = "${local.name_prefix}-vsphere-kickstarter"
  vm_password            = var.vm_password
  vi                     = module.vi
  remote_ovf_url         = var.photon_ovf_url
  vcsa_iso_datastore     = var.nested_vcsa.iso_datastore != "" ? var.nested_vcsa.iso_datastore : null
  vcsa_iso_path          = var.nested_vcsa.iso_path != "" ? var.nested_vcsa.iso_path : null
  vcsa_name              = local.vcsa_vmname
  vcsa_network_name      = "VM Network"
  vcsa_gateway           = var.gateway
  vcsa_ntp               = var.ntp
  vcsa_nameservers       = var.nameservers
  vcsa_ip                = var.nested_vcsa.ip
  vcsa_hostname          = var.nested_vcsa.hostname
  vcsa_domain_name       = var.domain_name
  vi_esxi_host           = var.nested_esxi_starting_ip
  vi_esxi_user           = "root"
  vi_esxi_password       = var.vm_password
  vcsa_datastore_name    = var.nested_vcsa.datastore
  vcsa_deployment_size   = var.nested_vcsa.deployment_option
  vcsa_password          = var.vm_password
  vcsa_subnet_mask       = var.subnet_mask
}

module "vcsa_standalone" {
  count             = var.nested_vcsa != null ? (!var.nested_vcsa.self_managed ? 1 : 0) : 0
  depends_on        = [module.vsphere_kickstarter, module.router]
  source            = "../../module/vcsa_standalone"
  ip                = var.nested_vcsa.ip
  hostname          = var.nested_vcsa.hostname
  domain_name       = var.domain_name
  subnet_mask       = var.subnet_mask
  vi                = module.vi
  remote_ovf_url    = var.nested_vcsa.remote_ovf_url
  name              = local.vcsa_vmname
  network_name      = var.network_name
  gateway           = var.gateway
  ntp               = var.ntp
  nameservers       = var.nameservers
  vm_password       = var.vm_password
  deployment_option = var.nested_vcsa.deployment_option
}

module "esxi_cluster" {
  source                      = "../../module/nested_esxi_cluster"
  depends_on                  = [module.storage]
  create_ks_server            = local.is_vcsa_self_managed ? false : true
  ks_server_ip                = local.is_vcsa_self_managed ? module.vsphere_kickstarter[0].ip : var.ks_server_ip
  ks_server_user              = "root"
  ks_server_www_dir           = "/srv/"
  bastion_ip                  = var.external_network != null ? module.router[0].wan_ip : null
  bastion_user                = var.external_network != null ? local.router_user : null
  bastion_password            = var.external_network != null ? var.vm_password : null
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
  photon_ovf_url              = var.photon_ovf_url
}

module "vsphere_provisioner" {
  source                          = "../../module/vsphere_provisioner"
  depends_on                      = [module.vcsa_standalone, module.vcsa_standalone]
  count                           = var.nested_vcsa != null ? 1 : 0
  vcsa_ip                         = var.nested_vcsa.ip
  vcsa_password                   = var.vm_password
  vcsa_username                   = "administrator@vsphere.local"
  vcsa_vmname                     = local.vcsa_vmname
  local_govc_path                 = "/usr/bin/govc"
  ip                              = module.vsphere_kickstarter[0].ip
  username                        = "root"
  password                        = var.vm_password
  bastion_ip                      = var.external_network != null ? module.router[0].wan_ip : null
  bastion_user                    = var.external_network != null ? local.router_user : null
  bastion_password                = var.external_network != null ? var.vm_password : null
  nested_esxi                     = values(tomap(module.esxi_cluster.esxi_hosts))
  ssh_private_key_openssh         = tls_private_key.ed25519.private_key_openssh
  dvs_list                        = var.vsphere_provisioner.dvs_list
  vsan_enabled                    = var.vsphere_provisioner.vsan_enabled
  ha_enabled                      = var.vsphere_provisioner.ha_enabled
  drs_enabled                     = var.vsphere_provisioner.drs_enabled
  nested_cluster_name             = var.vsphere_provisioner.cluster_name
  nested_datacenter_name          = var.vsphere_provisioner.datacenter_name
  nested_datastore_name           = var.provision_datastores[0].datastore_name
  nested_management_portroup_name = "VM Network"
  gateway                         = var.gateway
  nameservers                     = var.nameservers
  domain_name                     = var.domain_name
  ntp                             = var.ntp
  ovftool_path                    = var.vsphere_provisioner.ovftool_path
  nsx                             = var.nsx
}
