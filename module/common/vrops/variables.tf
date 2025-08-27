variable "vi" {}

variable "remote_ovf_url" { type = string }

variable "name" { type = string }

variable "wait_for_guest_ip_timeout" {
  default = 5
}
variable "wait_for_guest_net_timeout" {
  default = 0
}
variable "wait_for_guest_net_routable" {
  default = false
}

variable "gateway" { type = string }
variable "domain_name" { type = string }
variable "dns_server" { type = string }
variable "ip_address" { type = string }
variable "netmask" { type = string }
variable "deployment_option" { default = "small" }
variable "network_name" { type = string }