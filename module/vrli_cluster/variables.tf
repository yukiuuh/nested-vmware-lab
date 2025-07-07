variable "vi" {}
variable "name_prefix" { type = string }
variable "ssh_authorized_keys" { type = list(string) }

variable "single_node" { default = true }
variable "hostname_prefix" { default = "vrli" }
variable "starting_ip" { type = string }

variable "gateway" { type = string }
variable "nameservers" { type = list(string) }
variable "subnet_mask" {
  type    = string
  default = "255.255.255.0"
}
variable "domain_name" { default = "" }
variable "ntp" {
  type    = string
  default = ""
}
variable "vm_password" {
  default = "VMware123!"
}

variable "remote_ovf_url" { type = string }
variable "deployment_option" { default = "small" }
variable "network_name" { type = string }