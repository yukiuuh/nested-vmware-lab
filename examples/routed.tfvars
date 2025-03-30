vsphere_user     = "administrator@vsphere.local"
vsphere_password = "Password1!"
vsphere_server   = "vc01.example.com"
datacenter       = "Datacenter"
datastore        = "vsanDatastore"
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

name_prefix         = "hanayamay"
nameservers         = ["10.0.0.1"]
subnet_mask         = "255.255.255.0"
gateway             = "10.0.0.1"
ntp                 = "10.0.0.1"
domain_name         = "nested.lab"
network_name        = "LabNetwork" # Promiscuous mode or MAC Learning enabled, and VLAN trunking enabled
ssh_authorized_keys = []

storage_vmknics = {
  mtu                  = 1500
  storage1_starting_ip = "10.0.4.101"
  storage1_vlan        = 1004
  storage1_subnet      = "255.255.255.0"
  storage2_starting_ip = "10.0.5.101"
  storage2_vlan        = 1005
  storage2_subnet      = "255.255.255.0"
}
nested_esxi_hostname_prefix = "esxi"
nested_esxi_starting_ip     = "10.0.0.101"

iscsi_targets = [
  "10.0.4.10"
]
nfs_hosts = [{
  share          = "/pool01/nfs"
  ip             = "10.0.0.10"
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
  self_managed      = false
  remote_ovf_url    = ""
  iso_path          = "template/iso/VMware-VCSA-all-8.0.3-24022515.iso"
  iso_datastore     = "ISO"
  ip                = "10.0.0.100"
  hostname          = "vcsa01"
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
  storage1_ip   = "10.0.4.10"
  storage2_ip   = "10.0.5.10"
  ip            = "10.0.0.10"
}

external_network = {
  name        = "VM Network"
  subnet_mask = "255.255.255.0"
  gateway     = "192.168.1.1"
  nameservers = ["192.168.1.10"]
  ntp         = "ntp.nict.jp"
  ip          = "192.168.1.254" # gateway to lab network
}
