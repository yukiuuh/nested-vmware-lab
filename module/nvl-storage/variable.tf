variable "gateway" { type = string }
variable "nameservers" { type = list(string) }
variable "subnet_mask" {
  type    = string
  default = "255.255.255.0"
}
variable "domain_name" { type = string }

variable "ubuntu_ovf_url" { default = null }
variable "local_ovf_path" { default = null }
variable "vm_password" { default = "VMware123!" }

variable "network_name" { type = string }

variable "vi" {}
variable "name" {}

variable "num_cpus" {}
variable "mem_gb" {}

variable "ip" {
  nullable = true
  type     = string
}
variable "storage1_ip" {}
variable "storage2_ip" {}
variable "storage1_vlan" { type = number }
variable "storage2_vlan" { type = number }
variable "storage_mtu" { type = number }
variable "storage_subnet_mask" {
  type    = string
  default = "255.255.255.0"
}

variable "storage_disk_size_gb" {type = number}

variable "luns" {
  type = list(object({
    size_gb = number
    name    = string
  }))
  default = []
}

variable "zfs_compression" {
  default = "off" # or i.e. "zstd"
}

variable "zfs_nfs_dedup" {
  default = "off"
}

variable "ssh_authorized_keys" {
  default = []
  type    = list(string)
}
