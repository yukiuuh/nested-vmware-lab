variable "gateway" { type = string }
variable "nameservers" { type = list(string) }
variable "subnet_mask" {
  type    = string
  default = "255.255.255.0"
}
variable "remote_ovf_url" { default = null }
variable "vm_password" { default = "VMware123!" }

variable "management_network" { type = string }
variable "lab_network" { type = string }

variable "name" {}
variable "ip" {
  nullable = true
  type     = string
}
variable "monolith_storage_size_gb" { type = number }

variable "nested_network" {
  type = object({
    domain_name        = string
    network            = string
    mtu                = number
    vlan_starts_with   = number
    vlan_network_count = number
  })
  default = {
    domain_name        = "nested.lab"
    mtu                = 9000
    network            = "10.0.0.0"
    vlan_starts_with   = 1001
    vlan_network_count = 9
  }
}
variable "ssh_authorized_keys" {
  default = []
  type    = list(string)
}
