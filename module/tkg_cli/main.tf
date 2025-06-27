locals {
  tkg_cli_hostname = var.name
  tkg_cli_user     = "labadmin"
  tkg_cli_userdata = templatefile("${path.module}/templates/userdata.tftpl",
    {
      ssh_authorized_keys = var.ssh_authorized_keys
      password            = var.vm_password
      user                = local.tkg_cli_user
      hostname            = local.tkg_cli_hostname
      kubectl_url         = var.kubectl_url
      tanzu_cli_url       = var.tanzu_cli_url
      ssh_rsa_public_b64  = base64encode(var.ssh_rsa_public)
      ssh_rsa_private_b64 = base64encode(var.ssh_rsa_private)
    }
  )
}

module "tkg_cli" {
  source             = "../common/ubuntu"
  vi                 = var.vi
  name               = var.name
  remote_ovf_url     = var.ubuntu_ovf_url
  userdata           = local.tkg_cli_userdata
  network_interfaces = [var.network_name]
  num_cpus           = 4
  mem_gb             = 8
  disks = [
    {
      "label"       = "disk0"
      "size_gb"     = 50
      "unit_number" = 0
    }
  ]
}
