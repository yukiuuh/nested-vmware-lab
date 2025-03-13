
locals {
  cidr_prefix          = join(".", slice(split(".", var.nested_esxi_starting_ip), 0, 3))
  starting_host        = tonumber(element(split(".", var.nested_esxi_starting_ip), 3))
  storage1_ip_prefix   = var.storage_vmknics != null ? join(".", slice(split(".", var.storage_vmknics.storage1_starting_ip), 0, 3)) : ""
  starting_storage1_ip = var.storage_vmknics != null ? tonumber(element(split(".", var.storage_vmknics.storage1_starting_ip), 3)) : ""
  storage2_ip_prefix   = var.storage_vmknics != null ? join(".", slice(split(".", var.storage_vmknics.storage2_starting_ip), 0, 3)) : ""
  starting_storage2_ip = var.storage_vmknics != null ? tonumber(element(split(".", var.storage_vmknics.storage2_starting_ip), 3)) : ""

  ks_server_www_dir = var.create_ks_server ? "/srv" : var.ks_server_www_dir
  ks_server_user    = var.create_ks_server ? "root" : var.ks_server_user
  nested_esxi = {
    for i in range(var.nested_esxi_count) : i => ({
      ip                   = format("%s.%d", local.cidr_prefix, local.starting_host + i)
      hostname             = format("%s%02d", var.nested_esxi_hostname_prefix, i + 1)
      fqdn                 = format("%s%02d.%s", var.nested_esxi_hostname_prefix, i + 1, var.domain_name)
      storage1_ip          = format("%s.%d", local.storage1_ip_prefix, local.starting_storage1_ip + i)
      storage2_ip          = format("%s.%d", local.storage2_ip_prefix, local.starting_storage2_ip + i)
      provision_datastores = i != 0 ? [] : var.provision_datastores
    })
  }
}

module "ks_server" {
  count              = var.create_ks_server ? 1 : 0
  source             = "../kickstarter"
  name               = "${var.name_prefix}-kickstarter"
  vm_password        = var.vm_password
  vi                 = var.vi
  ks_server_ip       = var.ks_server_ip
  network_interfaces = [var.network_name]
  remote_ovf_url     = var.photon_ovf_url
}

module "nested_esxi_scratch" {
  depends_on         = [module.ks_server]
  source             = "../common/nested_esxi_scratch"
  for_each           = local.nested_esxi
  name               = "${var.name_prefix}-${each.value.hostname}"
  vi                 = var.vi
  network_interfaces = [for i in range(var.nested_esxi_shape.nic_count) : var.network_name]
  disks              = var.nested_esxi_shape.disks
  nvme_enabled       = var.nested_esxi_shape.nvme_enabled
  hostname           = "${each.value.hostname}.${var.domain_name}"
  management_vmknic = {
    ip      = each.value.ip
    subnet  = var.subnet_mask
    gateway = var.gateway
    vlan    = var.vlan
    mtu     = var.mtu
  }
  storage1_vmknic = var.storage_vmknics != null ? {
    ip     = each.value.storage1_ip
    subnet = var.storage_vmknics.storage1_subnet
    vlan   = var.storage_vmknics.storage1_vlan
    mtu    = var.storage_vmknics.mtu
  } : null
  storage2_vmknic = var.storage_vmknics != null ? {
    ip     = each.value.storage2_ip
    subnet = var.storage_vmknics.storage2_subnet
    vlan   = var.storage_vmknics.storage2_vlan
    mtu    = var.storage_vmknics.mtu

  } : null
  tpm_enabled          = var.nested_esxi_shape.tpm_enabled
  provision_datastores = each.value.provision_datastores
  domain_name          = var.domain_name
  ntp                  = var.ntp

  mem_gb   = var.nested_esxi_shape.mem_gb
  num_cpus = var.nested_esxi_shape.num_cpus

  dns                = element(var.nameservers, 0)
  password           = var.vm_password
  ks_server_password = var.ks_server_password
  ks_server_user     = local.ks_server_user
  ks_server_ip       = var.ks_server_ip
  ks_server_www_dir  = local.ks_server_www_dir
  iso_datastore      = var.esxi_iso_datastore
  iso_path           = var.esxi_iso_path
  nfs_hosts          = var.nfs_hosts
  iscsi_targets      = var.iscsi_targets
}

resource "terraform_data" "cleanup_kickstarter" {
  count      = var.create_ks_server ? 1 : 0
  depends_on = [module.nested_esxi_scratch]
  input = {
    vm_name = module.ks_server[0].vmname
  }
  provisioner "local-exec" {
    command = "govc vm.power -off -force ${self.input.vm_name}; govc vm.destroy ${self.input.vm_name}; echo 0"
    environment = {
      GOVC_URL        = var.vi.govc_url
      GOVC_INSECURE   = "true"
      GOVC_DATACENTER = var.vi.datacenter.name
    }
  }
}
