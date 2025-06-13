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
variable "name_prefix" {}

variable "local_govc_path" {
  default = "/usr/bin/govc"
}
variable "ovftool_path" {
  default = "/mnt/cdrom/vcsa/ovftool/lin64"
}

variable "nested_datacenter_name" { default = "Datacenter" }
variable "nested_cluster_name" { default = "Cluster" }
variable "nested_datastore_name" { default = "iscsi01" }
variable "nested_management_portroup_name" { default = "VM Network" }

variable "gateway" { type = string }
variable "nameservers" { type = list(string) }
variable "subnet_mask" {
  type    = string
  default = "255.255.255.0"
}
variable "domain_name" { type = string }
variable "ntp" { type = string }

variable "vsan_enabled" { default = false }
variable "ha_enabled" { default = false }
variable "drs_enabled" { default = false }

variable "nested_esxi" {}

variable "ssh_private_key_openssh" { default = "" }

variable "storage_policy_list" {
  default = []
  type = list(object({
    name      = string
    datastore = string
  }))
}

variable "content_library_list" {
  default = []
  type = list(object({
    name      = string
    datastore = string
  }))
}
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

variable "nsx" {
  nullable = true
  default  = null
  type = object({
    managed_by_terraform    = optional(bool, false)
    manager_ova_path        = string
    manager_ova             = string
    manager_deployment_size = string
    license                 = string
    password                = string
    username                = optional(string, "admin")
    managers = list(object({
      hostname = string
      ip       = string
    }))
    host_tep_ip_pool_gateway  = string
    host_tep_ip_pool_start_ip = string
    host_tep_ip_pool_end_ip   = string
    host_tep_ip_pool_cidr     = string
    host_tep_uplink_vlan      = number
    host_switch_name          = string
    host_switch_uplink_list = list(object({
      uplink_name     = string
      vds_uplink_name = string
    }))
    edge_deployment_size      = string
    edge_tep_ip_pool_gateway  = string
    edge_tep_ip_pool_start_ip = string
    edge_tep_ip_pool_end_ip   = string
    edge_tep_ip_pool_cidr     = string
    edge_tep_uplink_vlan      = number
    # external_uplink_vlan_list = list(number)
    external_uplink_vlan = number
    t0_gateway           = string
    edge_vm_list = list(object({
      management_ip = string
      hostname      = string
      t0_interfaces = list(object(
        {
          ip            = string
          prefix_length = string
        }
      ))
    }))
  })
}

variable "avi" {
  nullable = true
  default  = null
  type = object({
    managed_by_terraform = optional(bool, true)
    controller_ova_url   = string
    license              = string
    password             = string
    default_password     = string
    controllers = list(object(
      {
        hostname = string
        ip       = string
      }
    ))
    ipam_usable_networks = list(string)
    gateway              = string
    networks = list(object({
      name     = string
      network  = string
      begin_ip = string
      end_ip   = string
      type     = string
    }))
  })
}
