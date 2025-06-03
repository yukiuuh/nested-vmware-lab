variable "vi" {}
variable "name" {
  type = string
}
variable "num_cpus" {
  type    = number
  default = 4
}
variable "mem_gb" {
  type    = number
  default = 8
}
variable "hardware_version" {
  default  = null
  nullable = true
}
variable "network_interfaces" {
  default = []
}
variable "disks" {
  default = []
}
variable "hostname" {
  default = ""
}
variable "dns" {
  type = string
}
variable "ntp" {
  default = "time.vmware.com"
}
variable "tpm_enabled" {
  default = false
}
variable "nvme_enabled" {
  default = false
}

variable "management_vmknic" {
  type = object({
    ip      = string
    subnet  = string
    gateway = string
    vlan    = number
    mtu     = number
  })
}

variable "nfs_hosts" {
  type = list(object({
    ip             = string
    share          = string
    datastore_name = string
  }))
}
variable "storage1_vmknic" {
  nullable = true
  type = object({
    ip     = string
    subnet = string
    vlan   = number
    mtu    = number
  })
}

variable "storage2_vmknic" {
  nullable = true
  type = object({
    ip     = string
    subnet = string
    vlan   = number
    mtu    = number
  })
}

variable "iscsi_targets" {
  type = list(string)
}

variable "provision_datastores" {
  type = list(object({
    datastore_name = string
    path_name      = string
  }))
  default = []
}

variable "password" {
  default = "VMware1!"
}
variable "ssh_enabled" {
  default = true
}

variable "wait_for_guest_ip_timeout" {
  default = 0
}
variable "wait_for_guest_net_timeout" {
  default = 0
}
variable "wait_for_guest_net_routable" {
  default = false
}

variable "guest_id" {
  default = "vmkernel65Guest"
}

variable "iso_path" {}
variable "iso_datastore" {}

variable "ks_server_ip" {}
variable "ks_server_user" { default = "root" }
variable "ks_server_password" {}
variable "ks_server_www_dir" { default = "/var/www/html/" }
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
variable "vcf_mode" {
  default = false
}