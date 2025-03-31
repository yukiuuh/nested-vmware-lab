variable "vi" {}

variable "network_name" { type = string }
variable "vm_password" { default = "VMware123!" }
variable "name_prefix" { type = string }

variable "photon_ovf_url" { default = "https://packages.vmware.com/photon/5.0/GA/ova/photon-hw15-5.0-dde71ec57.x86_64.ova" }
variable "esxi_iso_datastore" {}
variable "esxi_iso_path" {}

variable "create_ks_server" { default = false }
variable "ks_server_ip" { nullable = true }
variable "ks_server_user" { default = "root" }
variable "ks_server_password" { default = "VMware123!" }
variable "ks_server_www_dir" { default = "/srv/" }

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
variable "gateway" { type = string }
variable "nameservers" { type = list(string) }
variable "subnet_mask" {
  type    = string
  default = "255.255.255.0"
}
variable "domain_name" {}
variable "mtu" {
  default = 1500
}

variable "vlan" { default = 0 }
variable "ntp" { default = "time.vmware.com" }

variable "nfs_hosts" {
  type = list(object({
    ip             = string
    share          = string
    datastore_name = string
  }))
  default = []
}
variable "iscsi_targets" {
  type    = list(string)
  default = []
}
variable "nested_esxi_count" {
  default = 3
}
variable "nested_esxi_starting_ip" {

}
variable "nested_esxi_hostname_prefix" {

}

variable "storage_vmknics" {
  nullable = true
  type = object({
    mtu                  = number
    storage1_starting_ip = string
    storage1_subnet      = string
    storage1_vlan        = number
    storage2_starting_ip = string
    storage2_subnet      = string
    storage2_vlan        = number
  })
}

variable "provision_datastores" {
  default = []
}
variable "nested_esxi_shape" {
  type = object({
    num_cpus     = number
    mem_gb       = number
    nic_count    = number
    tpm_enabled  = bool
    nvme_enabled = bool
    vcf_mode     = optional(bool, false)
    disks = list(object({
      label       = string
      size_gb     = number
      unit_number = number
    }))
  })
}