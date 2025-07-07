output "ip" {
  value = module.tkg_cli.vm_info.default_ip_address
}

output "name" {
  value = var.name
}

output "ssh_public_key" {
  value = var.ssh_rsa_public
}
