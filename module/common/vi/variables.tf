variable "datacenter" {
  type = string
}

variable "resource_pool" {
  type = string
}

variable "compute_host" {
  type = string
}

variable "datastore" {
  type = string
}

variable "networks" {
  type = set(string)
}
variable "vsphere_server" { type = string }
variable "vsphere_user" { type = string }
variable "vsphere_password" {
  type      = string
  sensitive = true
}