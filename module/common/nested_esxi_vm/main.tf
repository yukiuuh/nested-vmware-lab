terraform {
  required_providers {
    vsphere = {
      source = "vmware/vsphere"
    }
  }
}

locals {
  vtpms = var.tpm_enabled ? [1] : []

  filter_extra_config = merge({
    for i in range(length(var.network_interfaces)) :
    "ethernet${tostring(i)}.filter4.name" => "dvfilter-maclearn"
  })

  filter_on_failure_extra_config = merge({
    for i in range(length(var.network_interfaces)) :
    "ethernet${tostring(i)}.filter4.onFailure" => "failOpen"
  })
}

resource "vsphere_virtual_machine" "nested_esxi" {
  name                  = var.name
  num_cpus              = var.num_cpus
  num_cores_per_socket  = var.num_cpus
  memory                = var.mem_gb * 1024
  memory_reservation    = var.memory_reservation_enabled ? var.mem_gb * 1024 : 0
  datastore_id          = var.vi.datastore.id
  resource_pool_id      = var.vi.resource_pool.id
  host_system_id        = var.vi.compute_host.id
  guest_id              = var.guest_id
  firmware              = var.firmware
  scsi_type             = "pvscsi"
  nested_hv_enabled     = true
  hardware_version      = var.hardware_version
  annotation            = var.annotation
  nvme_controller_count = var.nvme_enabled ? 1 : 0
  force_power_off       = true
  enable_disk_uuid      = true

  lifecycle {
    ignore_changes = [
      host_system_id,
      disk,
    ]
  }

  dynamic "network_interface" {
    for_each = var.network_interfaces
    content {
      network_id = var.vi.networks[network_interface.value].id
    }
  }

  dynamic "disk" {
    for_each = var.disks
    content {
      label           = disk.value.label
      size            = disk.value.size_gb
      unit_number     = disk.value.unit_number
      controller_type = var.nvme_enabled ? "nvme" : "scsi"
    }
  }

  dynamic "vtpm" {
    for_each = local.vtpms
    content {
      version = "2.0"
    }
  }

  wait_for_guest_net_timeout  = 0
  wait_for_guest_ip_timeout   = 0
  wait_for_guest_net_routable = false

  extra_config_reboot_required = false
  extra_config                 = merge(local.filter_extra_config, local.filter_on_failure_extra_config)
}
