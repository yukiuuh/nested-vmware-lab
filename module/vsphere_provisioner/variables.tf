variable "vcsa_ip" {}
variable "vcsa_password" {}
variable "vcsa_username" { default = "administrator@vsphere.local" }
variable "vcsa_vmname" {}
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
variable "vsan_enabled" { default = false }
variable "ha_enabled" { default = false }
variable "drs_enabled" { default = false }

variable "nested_esxi" {}

variable "ssh_private_key_openssh" { default = "" }

variable "dvs_list" {
  type = list(object({
    name    = string
    version = string
    mtu     = string
    uplinks = list(string)
    portgroups = list(object({
      name    = string
      vlan_id = string
      vmknics = list(object({
        starting_ip            = string
        subnet_mask            = string
        mtu                    = string
        enable_vmotion         = optional(string, "False")
        enable_vsan            = optional(string, "False")
        enable_ft              = optional(string, "False")
        enable_mgmt            = optional(string, "False")
        enable_provisioning    = optional(string, "False")
        enable_replication_nfc = optional(string, "False")
        enable_backup_nfc      = optional(string, "False")
      }))
    }))
  }))
}
