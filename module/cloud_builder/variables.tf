variable "vi" {}
variable "name" {}
variable "network_name" { default = "VM Network" }
variable "ip" {}

variable "subnet_mask" {}
variable "nameservers" { type = list(string) }
variable "gateway" {}
variable "ntp" {}

variable "domain_name" {
  nullable = true
  default  = null
}
variable "hostname" {
  nullable = true
  default  = null
}

variable "remote_ovf_url" {}

variable "vm_password" { default = "VMware123!VMware123!" }