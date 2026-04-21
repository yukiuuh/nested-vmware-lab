terraform {
  required_providers {
    random = {
      source = "hashicorp/random"
    }
    vsphere = {
      source = "vmware/vsphere"
    }
  }
}

provider "vsphere" {
  allow_unverified_ssl = local.provider.insecure
  user                 = local.provider.user
  password             = local.provider.password
  vsphere_server       = local.provider.server
}

module "vi" {
  source = "../../module/common/vi"

  datacenter       = local.provider.datacenter
  resource_pool    = local.provider.resource_pool
  compute_host     = local.provider.compute_host
  datastore        = local.provider.datastore
  networks         = local.all_networks
  vsphere_server   = local.provider.server
  vsphere_user     = local.provider.user
  vsphere_password = local.provider.password
}
