
output "nsx_managers" {
  value = var.nsx != null ? [for manager in var.nsx.managers : {
    ip       = manager.ip
    hostname = "${manager.hostname}.${var.domain_name}"
    password = var.nsx.password
  }] : null
}