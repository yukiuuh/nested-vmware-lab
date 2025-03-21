vsphere_user     = "administrator@vsphere.local"
vsphere_password = "Password1!"
vsphere_server   = "vc01.example.com"
datacenter       = "Datacenter"
datastore        = "vsanDatasore"
resource_pool    = "Cluster/Resources"
compute_host     = "192.168.1.101"

nested_esxi_count = 3
nested_esxi_shape = {
  "num_cpus"     = 8
  "mem_gb"       = 24
  "nic_count"    = 8
  "tpm_enabled"  = false
  "nvme_enabled" = true
  "disks" = [
    {
      "label"       = "disk0"
      "size_gb"     = 40
      "unit_number" = 0
    },
    {
      "label"       = "disk1"
      "size_gb"     = 1
      "unit_number" = 1
    },
    {
      "label"       = "disk2"
      "size_gb"     = 1
      "unit_number" = 2
    },
  ]
}

esxi_iso_datastore = "ISO"
esxi_iso_path      = "/template/iso/VMware-VMvisor-Installer-8.0U3-24022510.x86_64.iso"

name_prefix  = "hanayamay"
nameservers  = ["192.168.1.10"]
subnet_mask  = "255.255.255.0"
gateway      = "192.168.1.1"
ntp          = "ntp.nict.jp"
domain_name  = "example.com"
network_name = "LabNetwork" # Promiscuous mode or MAC Learning enabled, and VLAN trunking enabled, with DNS and internet access
ssh_authorized_keys = []

storage_vmknics = {
  mtu                  = 1500
  storage1_starting_ip = "192.168.4.51"
  storage1_vlan        = 1004
  storage1_subnet      = "255.255.255.0"
  storage2_starting_ip = "192.168.5.51"
  storage2_vlan        = 1005
  storage2_subnet      = "255.255.255.0"
}
nested_esxi_hostname_prefix = "es"
nested_esxi_starting_ip     = "192.168.1.51"

iscsi_targets = [
  "192.168.4.100"
]
nfs_hosts = [{
  share          = "/pool01/nfs"
  ip             = "192.168.1.100"
  datastore_name = "nfs01"
}]
provision_datastores = [{
  datastore_name = "iscsi01"
  path_name      = "vmhba65:C0:T0:L0"
  },
  {
    datastore_name = "iscsi02"
    path_name      = "vmhba65:C0:T0:L1"
  }
]

nested_vcsa = {
  self_managed      = true
  ip                = "192.168.1.50"
  hostname          = "vc01"
  remote_ovf_url    = ""
  iso_path          = "template/iso/VMware-VCSA-all-8.0.3-24022515.iso"
  iso_datastore     = "ISO"
  datastore         = "iscsi01"
  deployment_option = "tiny"
}

storage = {
  storage1_vlan = 1004
  storage2_vlan = 1005
  mtu           = 1500
  subnet_mask   = "255.255.255.0"
  disk_size_gb  = 200
  lun_size_gb   = 200
  lun_count     = 4
  storage1_ip   = "192.168.4.100"
  storage2_ip   = "192.168.5.100"
  ip            = "192.168.1.100"
}

external_network = null
