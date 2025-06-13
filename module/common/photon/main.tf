locals {
  userdata           = base64encode(var.userdata)
  metadata           = base64encode(var.metadata)
  default_network_id = element(values(var.vi.networks), 0).id
}

data "vsphere_ovf_vm_template" "photon" {
  name              = "photon"
  disk_provisioning = "thin"
  resource_pool_id  = var.vi.resource_pool.id
  datastore_id      = var.vi.datastore.id
  host_system_id    = var.vi.compute_host.id
  remote_ovf_url    = var.remote_ovf_url
  ovf_network_map = {
    "None" : local.default_network_id
  }
}

resource "vsphere_virtual_machine" "photon_with_cloudinit" {
  name                 = var.name
  num_cpus             = var.num_cpus
  num_cores_per_socket = var.num_cpus
  memory               = var.mem_gb * 1024
  datacenter_id        = var.vi.datacenter.id
  datastore_id         = var.vi.datastore.id
  host_system_id       = var.vi.compute_host.id
  resource_pool_id     = var.vi.resource_pool.id
  guest_id             = data.vsphere_ovf_vm_template.photon.guest_id
  firmware             = data.vsphere_ovf_vm_template.photon.firmware
  scsi_type            = data.vsphere_ovf_vm_template.photon.scsi_type
  annotation           = var.annotation != "" ? var.annotation : data.vsphere_ovf_vm_template.photon.annotation
  force_power_off       = true

  lifecycle {
    ignore_changes = [
      host_system_id,
      disk[0].io_share_count,
      ovf_deploy[0].ovf_network_map
    ]
  }

  dynamic "network_interface" {
    for_each = var.network_interfaces
    content {
      network_id = var.vi.networks[network_interface.value].id
    }
  }

  dynamic "cdrom" {
    for_each = var.cdroms
    content {
      datastore_id = cdrom.value.datastore_id
      path         = cdrom.value.path
    }
  }

  wait_for_guest_net_timeout  = 0
  wait_for_guest_ip_timeout   = 30
  wait_for_guest_net_routable = var.wait_for_guest_net_routable

  ovf_deploy {
    allow_unverified_ssl_cert = true
    remote_ovf_url            = var.remote_ovf_url
    disk_provisioning         = "thin"
    ovf_network_map = {
      "None" : local.default_network_id
    }
  }

  extra_config = {
    "guestinfo.userdata"          = local.userdata,
    "guestinfo.userdata.encoding" = "base64",
    "guestinfo.metadata"          = local.metadata,
    "guestinfo.metadata.encoding" = "base64"
  }
}
