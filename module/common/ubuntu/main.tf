
locals {
  userdata           = base64encode(var.userdata)
  default_network_id = element(values(var.vi.networks), 0).id
}

data "vsphere_ovf_vm_template" "ubuntu" {
  name              = "ubuntu"
  disk_provisioning = "thin"
  resource_pool_id  = var.vi.resource_pool.id
  datastore_id      = var.vi.datastore.id
  host_system_id    = var.vi.compute_host.id
  remote_ovf_url    = var.remote_ovf_url
  ovf_network_map = {
    "VM Network" : local.default_network_id
  }
}

resource "vsphere_virtual_machine" "ubuntu" {
  name                 = var.name
  num_cpus             = var.num_cpus
  num_cores_per_socket = var.num_cpus
  memory               = var.mem_gb * 1024
  datacenter_id        = var.vi.datacenter.id
  datastore_id         = var.vi.datastore.id
  host_system_id       = var.vi.compute_host.id
  resource_pool_id     = var.vi.resource_pool.id
  guest_id             = data.vsphere_ovf_vm_template.ubuntu.guest_id
  firmware             = data.vsphere_ovf_vm_template.ubuntu.firmware
  scsi_type            = data.vsphere_ovf_vm_template.ubuntu.scsi_type
  force_power_off      = true

  lifecycle {
    ignore_changes = [
      host_system_id,
      disk[0].io_share_count,
      disk[1].io_share_count,
      ovf_deploy[0].ovf_network_map,
      cdrom[0],
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
      datastore_id  = cdrom.value.datastore_id
      path          = cdrom.value.path
      client_device = cdrom.value.client_device
    }
  }

  cdrom {
    client_device = true
  }

  dynamic "disk" {
    for_each = var.disks
    content {
      label       = disk.value.label
      size        = disk.value.size_gb
      unit_number = disk.value.unit_number
    }
  }

  wait_for_guest_net_timeout  = 30
  wait_for_guest_ip_timeout   = 30
  wait_for_guest_net_routable = var.wait_for_guest_net_routable

  ovf_deploy {
    allow_unverified_ssl_cert = true
    remote_ovf_url            = var.remote_ovf_url
    disk_provisioning         = "thin"
    ovf_network_map = {
      "VM Network" : local.default_network_id
    }
  }

  vapp {
    properties = {
      "user-data" = local.userdata
    }
  }
}
