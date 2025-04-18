output "ip" {
  value = var.ip
}

output "hostname" {
  value = "${var.hostname}.${var.domain_name}"
}

output "password" {
  value = var.vm_password
}

output "name" {
  value = var.name
}

output "source" {
  value = basename(var.remote_ovf_url)
}