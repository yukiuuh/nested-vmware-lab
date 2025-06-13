locals {
  network_id = var.vi.networks[var.network_name].id
}

data "vsphere_ovf_vm_template" "avi_controller_source" {
  name              = "avi_controller"
  disk_provisioning = "thin"
  resource_pool_id  = var.vi.resource_pool.id
  datastore_id      = var.vi.datastore.id
  host_system_id    = var.vi.compute_host.id
  remote_ovf_url    = var.remote_ovf_url
  ovf_network_map = {
    "Management" : local.network_id
  }
}

resource "vsphere_virtual_machine" "avi_controller" {
  name             = var.name
  datacenter_id    = var.vi.datacenter.id
  datastore_id     = var.vi.datastore.id
  resource_pool_id = var.vi.resource_pool.id
  host_system_id   = var.vi.compute_host.id
  guest_id         = data.vsphere_ovf_vm_template.avi_controller_source.guest_id
  # firmware             = data.vsphere_ovf_vm_template.avi_controller_source.firmware
  scsi_type       = data.vsphere_ovf_vm_template.avi_controller_source.scsi_type
  num_cpus        = data.vsphere_ovf_vm_template.avi_controller_source.num_cpus
  memory          = data.vsphere_ovf_vm_template.avi_controller_source.memory
  force_power_off = true

  lifecycle {
    ignore_changes = [
      vapp[0].properties,
      host_system_id,
      disk[0].io_share_count,
      disk[1].io_share_count,
      disk[2].io_share_count
    ]
  }

  wait_for_guest_net_timeout  = var.wait_for_guest_net_timeout
  wait_for_guest_ip_timeout   = var.wait_for_guest_ip_timeout
  wait_for_guest_net_routable = var.wait_for_guest_net_routable

  extra_config_reboot_required = false
  ovf_deploy {
    remote_ovf_url    = data.vsphere_ovf_vm_template.avi_controller_source.remote_ovf_url
    disk_provisioning = "thin"
    ovf_network_map = {
      "Management" : local.network_id
    }
  }

  network_interface {
    network_id = local.network_id
  }

  vapp {
    properties = {
      "mgmt-ip"             = var.ip_address
      "mgmt-mask"           = var.netmask
      "default-gw"          = var.gateway
    }
  }
}
