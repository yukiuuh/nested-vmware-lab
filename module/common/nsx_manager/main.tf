locals {
  network_id = var.vi.networks[var.network_name].id
}

data "vsphere_ovf_vm_template" "nsx_manager_source" {
  name              = "nsx_manager"
  disk_provisioning = "thin"
  resource_pool_id  = var.vi.resource_pool.id
  datastore_id      = var.vi.datastore.id
  host_system_id    = var.vi.compute_host.id
  remote_ovf_url    = var.remote_ovf_url
  ovf_network_map = {
    "Network 1" : local.network_id
  }
  deployment_option = var.deployment_option
}

resource "vsphere_virtual_machine" "nsx_manager" {
  name             = var.name
  datacenter_id    = var.vi.datacenter.id
  datastore_id     = var.vi.datastore.id
  resource_pool_id = var.vi.resource_pool.id
  host_system_id   = var.vi.compute_host.id
  guest_id         = data.vsphere_ovf_vm_template.nsx_manager_source.guest_id
  # firmware             = data.vsphere_ovf_vm_template.nsx_manager_source.firmware
  scsi_type       = data.vsphere_ovf_vm_template.nsx_manager_source.scsi_type
  num_cpus        = data.vsphere_ovf_vm_template.nsx_manager_source.num_cpus
  memory          = data.vsphere_ovf_vm_template.nsx_manager_source.memory
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
    remote_ovf_url    = data.vsphere_ovf_vm_template.nsx_manager_source.remote_ovf_url
    disk_provisioning = "thin"
    ovf_network_map = {
      "Network 1" : local.network_id
    }
    deployment_option = var.deployment_option
  }

  network_interface {
    network_id = local.network_id
  }

  vapp {
    properties = {
      "nsx_role"               = var.role
      "nsx_ip_0"               = var.ip_address
      "nsx_netmask_0"          = var.netmask
      "nsx_gateway_0"          = var.gateway
      "nsx_dns1_0"             = var.dns_server
      "nsx_domain_0"           = var.domain_name
      "nsx_ntp_0"              = var.ntp
      "nsx_isSSHEnabled"       = var.ssh_enabled ? "True" : "False"
      "nsx_allowSSHRootLogin"  = var.allow_ssh_root_login ? "True" : "False"
      "nsx_passwd_0"           = var.vm_password
      "nsx_cli_passwd_0"       = var.vm_password
      "nsx_cli_audit_passwd_0" = var.vm_password
      "nsx_hostname"           = var.hostname
    }
  }
}