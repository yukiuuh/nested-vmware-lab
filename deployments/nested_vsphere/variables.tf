variable "vsphere_server" { type = string }
variable "vsphere_user" { type = string }
variable "vsphere_password" {
  type      = string
  sensitive = true
}
variable "datacenter" { type = string }
variable "resource_pool" { type = string }
variable "compute_host" { type = string }
variable "datastore" { type = string }
variable "network_name" { type = string }

variable "vm_password" { default = "VMware123!" }
variable "name_prefix" { type = string }

variable "photon_ovf_url" { default = "https://packages.vmware.com/photon/5.0/GA/ova/photon-hw15-5.0-dde71ec57.x86_64.ova" }
variable "ubuntu_ovf_url" { default = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.ova" }
variable "esxi_iso_datastore" {}
variable "esxi_iso_path" {}

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

variable "ssh_authorized_keys" {
  default = []
  type    = list(string)
}

variable "ks_server_ip" {
  nullable = true
  default  = null
}

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
  default  = null
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
  type = list(object({
    datastore_name = string
    path_name      = string
  }))
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

variable "nested_vcsa" {
  nullable = true
  default  = null
  type = object({
    self_managed      = bool
    ip                = string
    hostname          = string
    remote_ovf_url    = string
    iso_path          = string
    iso_datastore     = string
    datastore         = string
    deployment_option = string
  })
}

variable "storage" {
  nullable = true
  default  = null
  type = object({
    ip            = string
    storage1_ip   = string
    storage2_ip   = string
    storage1_vlan = number
    storage2_vlan = number
    mtu           = number
    subnet_mask   = string
    disk_size_gb  = number
    lun_size_gb   = number
    lun_count     = number
  })
}

variable "external_network" {
  nullable = true
  default  = null
  type = object({
    name        = string
    subnet_mask = string
    gateway     = string
    nameservers = list(string)
    ntp         = string
    ip          = string
  })
}

variable "lab_network" {
  nullable = true
  default = {
    domain_name        = "nested.lab"
    mtu                = 1700
    network            = "10.0.0.0"
    vlan_starts_with   = 1001
    vlan_network_count = 20
  }
  type = object({
    domain_name        = string
    network            = string
    mtu                = number
    vlan_starts_with   = number
    vlan_network_count = number
  })
}

variable "nsx" {
  nullable = true
  default  = null
  type = object({
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

variable "vsphere_provisioner" {
  nullable = true
  default  = null
  type = object({
    datacenter_name = optional(string)
    cluster_name    = optional(string)
    vsan_enabled    = optional(bool, false)
    drs_enabled     = optional(bool, true)
    ha_enabled      = optional(bool, true)
    ovftool_path    = optional(string, "/mnt/cdrom/vcsa/ovftool/lin64")
    storage_policy_list = optional(list(object({
      name      = string
      datastore = string
    })), [])
    dvs_list = list(object({
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
  })
}
