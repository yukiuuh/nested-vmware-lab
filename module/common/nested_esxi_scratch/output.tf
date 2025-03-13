output "ip" {
  value = var.management_vmknic.ip
}

output "hostname" {
  value = var.hostname
}

output "fqdn" {
  value = "${var.hostname}.${var.domain_name}"
}

output "password" {
  value = var.password
}
