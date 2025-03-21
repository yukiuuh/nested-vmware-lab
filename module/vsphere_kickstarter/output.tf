output "name" {
  value = var.name
}

output "ip" {
  value = module.vsphere_kickstarter_photon.photon.default_ip_address
}

output "info" {
  value = module.vsphere_kickstarter_photon.photon
}


output "vcsa_info" {
  value = {
    ip       = var.vcsa_ip
    hostname = "${var.vcsa_hostname}.${var.vcsa_domain_name}"
    password = var.vm_password
  }
}

