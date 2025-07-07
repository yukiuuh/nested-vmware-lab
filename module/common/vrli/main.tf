locals {
  network_id = var.vi.networks[var.network_name].id
}
data "vsphere_ovf_vm_template" "vrli_source" {
  name              = "vrli"
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

resource "vsphere_virtual_machine" "vrli" {
  name             = var.name
  datacenter_id    = var.vi.datacenter.id
  datastore_id     = var.vi.datastore.id
  resource_pool_id = var.vi.resource_pool.id
  host_system_id   = var.vi.compute_host.id
  guest_id         = data.vsphere_ovf_vm_template.vrli_source.guest_id
  # firmware             = data.vsphere_ovf_vm_template.vrli_source.firmware
  scsi_type = data.vsphere_ovf_vm_template.vrli_source.scsi_type
  num_cpus  = data.vsphere_ovf_vm_template.vrli_source.num_cpus
  memory    = data.vsphere_ovf_vm_template.vrli_source.memory

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
    remote_ovf_url    = data.vsphere_ovf_vm_template.vrli_source.remote_ovf_url
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
      "rootpw"     = var.vm_password
      "hostname"   = var.fqdn
      "sshkey"     = var.authorized_key
      "gateway"    = var.gateway
      "domain"     = var.domain_name
      "searchpath" = var.domain_name
      "DNS"        = var.dns_server
      "ip0"        = var.ip_address
      "netmask0"   = var.netmask
    }
  }
}