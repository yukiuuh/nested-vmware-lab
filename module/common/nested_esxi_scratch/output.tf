output "ip" {
  value = var.management_vmknic.ip
}

output "hostname" {
  value = var.hostname
}

output "password" {
  value = var.password
}
output "name" {
  value = var.name
}

output "source" {
  value = basename(var.iso_path)
}