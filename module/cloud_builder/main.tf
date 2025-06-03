module "cloud_builder_address" {
  source     = "../common/netmask2prefix"
  ip_address = var.ip
  netmask    = var.subnet_mask
}

data "vsphere_ovf_vm_template" "cloud_builder" {
  name              = "cloud_builder_ova"
  remote_ovf_url    = var.remote_ovf_url
  disk_provisioning = "thin"
  resource_pool_id  = var.vi.resource_pool.id
  datastore_id      = var.vi.datastore.id
  host_system_id    = var.vi.compute_host.id
  ovf_network_map = {
    "Network 1" : var.vi.networks[var.network_name].id
  }
  enable_hidden_properties = true
}

locals {
  vapp_properties = {
    "guestinfo.ROOT_PASSWORD"  = var.vm_password
    "guestinfo.ADMIN_PASSWORD" = var.vm_password
    "guestinfo.ntp"            = var.ntp
    "guestinfo.hostname"       = "${var.hostname}.${var.domain_name}"
    "guestinfo.ip0"            = var.ip
    "guestinfo.netmask0"       = var.subnet_mask
    "guestinfo.gateway"        = var.gateway
    "guestinfo.domain"         = var.domain_name
    "guestinfo.searchpath"     = var.domain_name
    "guestinfo.DNS"            = join(",", var.nameservers)
  }
}

resource "vsphere_virtual_machine" "cloud_builder" {
  depends_on           = [data.vsphere_ovf_vm_template.cloud_builder]
  name                 = var.name
  datacenter_id        = var.vi.datacenter.id
  resource_pool_id     = var.vi.resource_pool.id
  datastore_id         = var.vi.datastore.id
  host_system_id       = var.vi.compute_host.id
  num_cpus             = data.vsphere_ovf_vm_template.cloud_builder.num_cpus
  num_cores_per_socket = data.vsphere_ovf_vm_template.cloud_builder.num_cores_per_socket
  memory               = data.vsphere_ovf_vm_template.cloud_builder.memory
  guest_id             = data.vsphere_ovf_vm_template.cloud_builder.guest_id
  scsi_type            = data.vsphere_ovf_vm_template.cloud_builder.scsi_type

  dynamic "network_interface" {
    for_each = data.vsphere_ovf_vm_template.cloud_builder.ovf_network_map
    content {
      network_id = network_interface.value
    }
  }

  ovf_deploy {
    allow_unverified_ssl_cert = true
    remote_ovf_url            = data.vsphere_ovf_vm_template.cloud_builder.remote_ovf_url
    disk_provisioning         = data.vsphere_ovf_vm_template.cloud_builder.disk_provisioning
    ovf_network_map           = data.vsphere_ovf_vm_template.cloud_builder.ovf_network_map
    enable_hidden_properties  = data.vsphere_ovf_vm_template.cloud_builder.enable_hidden_properties
  }

  vapp {
    properties = local.vapp_properties
  }

  lifecycle {
    ignore_changes = [
      num_cores_per_socket,
      vapp[0].properties,
      host_system_id
    ]
  }
}
