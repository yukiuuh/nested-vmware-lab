variable "vi" {}

variable "remote_ovf_url" { type = string }

variable "name" { type = string }

variable "wait_for_guest_ip_timeout" {
  default = 30
}
variable "wait_for_guest_net_timeout" {
  default = 0
}
variable "wait_for_guest_net_routable" {
  default = false
}

variable "vm_password" { type = string }
variable "hostname" { type = string }
variable "gateway" { type = string }
variable "domain_name" { type = string }
variable "dns_server" { type = string }
variable "ip_address" { type = string }
variable "netmask" {
  type = string
}
# variable "authorized_key" { type = string }
variable "deployment_option" { type = string }
variable "role" { type = string }
variable "ntp" { type = string }
variable "ssh_enabled" { default = true }
variable "allow_ssh_root_login" { default = true }
variable "network_name" {}
