output "ip" {
  value = var.ip
}

output "hostname" {
  value = var.pnid != null ? var.pnid : "${var.hostname}.${var.domain_name}"
}

output "password" {
  value = var.vm_password
}

output "govc_url" {
  value = local.vcsa_govc_url
}
