variable "vcsa_ip" {}
variable "vcsa_password" {}
variable "vcsa_username" { default = "administrator@vsphere.local" }

variable "bastion_ip" {
  nullable = true
  default  = null
}
variable "bastion_user" {
  nullable = true
  default  = null
}
variable "bastion_password" {
  nullable = true
  default  = null
}

variable "ip" {}
variable "password" {}
variable "username" {}

variable "local_govc_path" {
  default = "/usr/bin/govc"
}

variable "nested_datacenter_name" { default = "Datacenter" }
variable "nested_cluster_name" { default = "Cluster" }
variable "nested_esxi" {}

variable "ssh_private_key_openssh" { default = "" }