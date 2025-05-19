module "vcsa_address" {
  source     = "../common/netmask2prefix"
  ip_address = var.ip
  netmask    = var.subnet_mask
}

data "vsphere_ovf_vm_template" "vcsa" {
  name              = "vcsa_ova"
  remote_ovf_url    = var.remote_ovf_url
  disk_provisioning = "thin"
  resource_pool_id  = var.vi.resource_pool.id
  datastore_id      = var.vi.datastore.id
  host_system_id    = var.vi.compute_host.id
  ovf_network_map = {
    "Network 1" : var.vi.networks[var.network_name].id
  }
  enable_hidden_properties = true
  deployment_option        = var.deployment_option
}

locals {
  cis_upgrade_import_directory = "/storage/seat/cis-export-folder"
  sso_administrator            = "administrator@${var.sso_domain_name}"
  vcsa_govc_url                = "https://${local.sso_administrator}:${urlencode(var.vm_password)}@${var.ip}/sdk"
}

resource "vsphere_virtual_machine" "vcsa" {
  depends_on           = [data.vsphere_ovf_vm_template.vcsa]
  name                 = var.name
  datacenter_id        = var.vi.datacenter.id
  resource_pool_id     = var.vi.resource_pool.id
  datastore_id         = var.vi.datastore.id
  host_system_id       = var.vi.compute_host.id
  num_cpus             = data.vsphere_ovf_vm_template.vcsa.num_cpus
  num_cores_per_socket = data.vsphere_ovf_vm_template.vcsa.num_cores_per_socket
  memory               = data.vsphere_ovf_vm_template.vcsa.memory
  guest_id             = data.vsphere_ovf_vm_template.vcsa.guest_id
  scsi_type            = data.vsphere_ovf_vm_template.vcsa.scsi_type

  dynamic "network_interface" {
    for_each = data.vsphere_ovf_vm_template.vcsa.ovf_network_map
    content {
      network_id = network_interface.value
    }
  }

  ovf_deploy {
    allow_unverified_ssl_cert = true
    remote_ovf_url            = data.vsphere_ovf_vm_template.vcsa.remote_ovf_url
    disk_provisioning         = data.vsphere_ovf_vm_template.vcsa.disk_provisioning
    ovf_network_map           = data.vsphere_ovf_vm_template.vcsa.ovf_network_map
    deployment_option         = var.deployment_option
    enable_hidden_properties  = data.vsphere_ovf_vm_template.vcsa.enable_hidden_properties
  }

  vapp {
    properties = {
      "guestinfo.cis.deployment.autoconfig"     = "True"
      "guestinfo.cis.deployment.node.type"      = "embedded"
      "guestinfo.cis.system.vm0.port"           = "443"
      "guestinfo.cis.appliance.net.addr.family" = "ipv4"
      "guestinfo.cis.appliance.net.mode"        = "static"
      "guestinfo.cis.appliance.net.pnid"        = var.pnid != null ? var.pnid : "${var.hostname}.${var.domain_name}"
      "guestinfo.cis.appliance.net.addr"        = var.ip
      "guestinfo.cis.appliance.net.prefix"      = module.vcsa_address.prefix_length
      "guestinfo.cis.appliance.net.gateway"     = var.gateway
      "guestinfo.cis.appliance.net.dns.servers" = join(",", var.nameservers)
      "guestinfo.cis.appliance.ntp.servers"     = var.ntp
      "guestinfo.cis.appliance.ssh.enabled"     = var.ssh_enabled ? "True" : "False"
      "guestinfo.cis.appliance.root.passwd"     = var.vm_password
      "guestinfo.cis.appliance.root.shell"      = "/bin/appliancesh"
      "guestinfo.cis.vmdir.site-name"           = "Default-First-Site"
      "guestinfo.cis.vmdir.username"            = local.sso_administrator
      "guestinfo.cis.vmdir.domain-name"         = var.sso_domain_name
      "guestinfo.cis.vmdir.password"            = var.vm_password
      "guestinfo.cis.upgrade.import.directory"  = local.cis_upgrade_import_directory
      "guestinfo.cis.vmdir.first-instance"      = "True"
      "guestinfo.cis.ceip_enabled"              = "True"
    }
  }

  lifecycle {
    ignore_changes = [
      num_cores_per_socket,
      vapp[0].properties,
      host_system_id
    ]
  }

  provisioner "local-exec" {
    command = "until govc guest.run -l 'root:${var.vm_password}' -vm ${var.name} stat /var/log/firstboot/succeeded ; do sleep 60 ; done"
    environment = {
      GOVC_URL      = var.vi.govc_url
      GOVC_INSECURE = "true"
    }
  }
}