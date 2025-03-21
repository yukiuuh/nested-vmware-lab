output "name" {
  value = var.name
}

output "ip" {
  value = module.kickstarter_photon.photon.default_ip_address
}

output "info" {
  value = module.kickstarter_photon.photon
}