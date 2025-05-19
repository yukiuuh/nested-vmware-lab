variable "gateway" { type = string }
variable "nameservers" { type = list(string) }
variable "subnet_mask" {
  type    = string
  default = "255.255.255.0"
}
variable "ubuntu_ovf_url" { default = null }
variable "vm_password" { default = "VMware123!" }

variable "wan_network_name" { type = string }
variable "network_name" { type = string }

variable "name" {}
variable "ip" {
  nullable = true
  type     = string
}
variable "vi" {}

variable "nested_network" {
  type = object({
    domain_name        = string
    network            = string
    mtu                = number
    vlan_starts_with   = number
    vlan_network_count = number
  })
}
variable "ssh_authorized_keys" {
  default = []
  type    = list(string)
}

variable "http_proxy_port" {
  default  = 3128
  type     = number
  nullable = false
}