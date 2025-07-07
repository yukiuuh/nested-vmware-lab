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

variable "gateway" { type = string }
variable "ip_address" { type = string }
variable "netmask" {
  type = string
}
# variable "authorized_key" { type = string }

variable "network_name" {}
