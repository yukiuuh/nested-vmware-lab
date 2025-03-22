module "vsphere_kickstarter_address" {
  source     = "../common/netmask2prefix"
  ip_address = var.vsphere_kickstarter_ip != null ? var.vsphere_kickstarter_ip : "0.0.0.0"
  netmask    = var.subnet_mask
}

module "vcsa_address" {
  source     = "../common/netmask2prefix"
  ip_address = var.vcsa_ip
  netmask    = var.vcsa_subnet_mask
}

locals {
  vm_password       = var.vsphere_kickstarter_password
  sso_administrator = "administrator@${var.vcsa_sso_domain_name}"
  vcsa_govc_url     = "https://${local.sso_administrator}:${urlencode(var.vm_password)}@${var.vcsa_ip}/sdk"

  deploy_vcsa = templatefile("${path.module}/templates/deploy_vcsa.sh.tftpl", {
    vm_name                      = var.vcsa_name
    datastore_name               = var.vcsa_datastore_name
    deployment_size              = var.vcsa_deployment_size
    network_name                 = var.vcsa_network_name
    pnid                         = "${var.vcsa_hostname}.${var.vcsa_domain_name}"
    ip                           = var.vcsa_ip
    prefix                       = module.vcsa_address.prefix_length
    gateway                      = var.vcsa_gateway
    nameserver                   = join(",", var.vcsa_nameservers)
    ntp                          = var.vcsa_ntp
    sso_domain_name              = var.vcsa_sso_domain_name
    vm_password                  = var.vcsa_password
    cis_upgrade_import_directory = "/storage/seat/cis-export-folder"
    esxi_password                = urlencode(var.vi_esxi_password)
    esxi_host                    = var.vi_esxi_host
    esxi_user                    = var.vi_esxi_user
    ssh_enabled                  = var.vcsa_ssh_enabled ? "True" : "False"
  })

  userdata = templatefile("${path.module}/templates/userdata.tftpl",
    {
      password           = local.vm_password
      deploy_vcsa_base64 = base64encode(local.deploy_vcsa)
      is_self_managed    = var.vcsa_iso_datastore != null
  })
  metadata = templatefile("${path.module}/templates/metadata.tftpl",
    {
      ip_address    = var.vsphere_kickstarter_ip != null ? var.vsphere_kickstarter_ip : ""
      subnet_prefix = module.vsphere_kickstarter_address.prefix_length
      gateway       = var.gateway
      nameservers   = var.vcsa_nameservers
  })
}

data "vsphere_datastore" "iso_datastore" {
  count         = var.vcsa_iso_datastore != null ? 1 : 0
  name          = var.vcsa_iso_datastore
  datacenter_id = var.vi.datacenter.id
}
module "vsphere_kickstarter_photon" {
  source             = "../common/photon"
  vi                 = var.vi
  name               = var.name
  annotation         = join("", ["Temporary VM for vCenter Server ${var.vcsa_name}", var.vcsa_iso_datastore != null ? "from [${var.vcsa_iso_datastore}] ${var.vcsa_iso_path}" : ""])
  userdata           = local.userdata
  metadata           = local.metadata
  network_interfaces = var.network_interfaces
  remote_ovf_url     = var.remote_ovf_url
  num_cpus           = 2
  mem_gb             = 1
  cdroms = var.vcsa_iso_datastore != null ? [
    {
      datastore_id = data.vsphere_datastore.iso_datastore[0].id
      path         = var.vcsa_iso_path
    }
  ] : []
}

resource "terraform_data" "wait_for_vsphere_kickstarter" {
  depends_on = [module.vsphere_kickstarter_photon]
  input = {
    name     = var.name
    password = var.vsphere_kickstarter_password
  }
  provisioner "local-exec" {
    command = "until govc guest.ls -l 'root:${self.input.password}' -vm ${self.input.name} /var/tmp/provisioned ; do sleep 60 ; done"
    environment = {
      GOVC_URL        = var.vi.govc_url
      GOVC_INSECURE   = "true"
      GOVC_DATACENTER = var.vi.datacenter.name
    }
  }
}

