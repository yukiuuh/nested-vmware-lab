variable "vi" {}
variable "deployment_option" { default = "tiny" }
variable "name" {}
variable "network_name" { default = "VM Network" }
variable "ip" {}
variable "ssh_enabled" { default = true }
variable "subnet_mask" {}
variable "nameservers" { type = list(string) }
variable "gateway" {}
variable "ntp" {}
variable "sso_domain_name" { default = "vsphere.local" }
variable "domain_name" {
  nullable = true
  default  = null
}
variable "hostname" {
  nullable = true
  default  = null
}
variable "pnid" {
  nullable = true
  default  = null
}
variable "remote_ovf_url" {}

variable "vm_password" { default = "VMware1!" }

