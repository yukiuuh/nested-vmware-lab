module "vcf_installer_address" {
  source     = "../common/netmask2prefix"
  ip_address = var.ip
  netmask    = var.subnet_mask
}

data "vsphere_ovf_vm_template" "vcf_installer" {
  name              = "vcf_installer_ova"
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


resource "vsphere_virtual_machine" "vcf_installer" {
  depends_on           = [data.vsphere_ovf_vm_template.vcf_installer]
  name                 = var.name
  datacenter_id        = var.vi.datacenter.id
  resource_pool_id     = var.vi.resource_pool.id
  datastore_id         = var.vi.datastore.id
  host_system_id       = var.vi.compute_host.id
  num_cpus             = data.vsphere_ovf_vm_template.vcf_installer.num_cpus
  num_cores_per_socket = data.vsphere_ovf_vm_template.vcf_installer.num_cores_per_socket
  memory               = data.vsphere_ovf_vm_template.vcf_installer.memory
  guest_id             = data.vsphere_ovf_vm_template.vcf_installer.guest_id
  scsi_type            = data.vsphere_ovf_vm_template.vcf_installer.scsi_type

  dynamic "network_interface" {
    for_each = data.vsphere_ovf_vm_template.vcf_installer.ovf_network_map
    content {
      network_id = network_interface.value
    }
  }

  ovf_deploy {
    allow_unverified_ssl_cert = true
    remote_ovf_url            = data.vsphere_ovf_vm_template.vcf_installer.remote_ovf_url
    disk_provisioning         = data.vsphere_ovf_vm_template.vcf_installer.disk_provisioning
    ovf_network_map           = data.vsphere_ovf_vm_template.vcf_installer.ovf_network_map
    enable_hidden_properties  = data.vsphere_ovf_vm_template.vcf_installer.enable_hidden_properties
  }

  vapp {
    properties = {
      "ROOT_PASSWORD"       = var.vm_password
      "LOCAL_USER_PASSWORD" = var.vm_password
      "VCF_PASSWORD"        = var.vm_password
      "guestinfo.ntp"       = var.ntp
      "vami.hostname"       = "${var.hostname}.${var.domain_name}"
      "ip0"                 = var.ip
      "netmask0"            = var.subnet_mask
      "gateway"             = var.gateway
      "domain"              = var.domain_name
      "searchpath"          = var.domain_name
      "DNS"                 = join(",", var.nameservers)
    }
  }

  lifecycle {
    ignore_changes = [
      num_cores_per_socket,
      vapp[0].properties,
      host_system_id
    ]
  }
}
