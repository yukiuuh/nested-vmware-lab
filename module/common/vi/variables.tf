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
variable "vsphere_server" {
  type     = string
  default  = null
  nullable = true
}
variable "vsphere_user" {
  type     = string
  default  = null
  nullable = true
}
variable "vsphere_password" {
  type      = string
  default   = null
  nullable  = true
  sensitive = true
}
