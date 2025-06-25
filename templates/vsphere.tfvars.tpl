{{- $config := datasource "config" -}}

vsphere_server   = "{{ $config.vsphere_server }}"
vsphere_user     = "{{ $config.vsphere_user }}"
vsphere_password = "{{ $config.vsphere_password }}"

datacenter    = "{{ $config.datacenter }}"
datastore     = "{{ $config.datastore }}"
resource_pool = "{{ $config.resource_pool }}"
compute_host  = "{{ $config.compute_host }}"

name_prefix         = "{{ $config.name_prefix }}"
network_name        = "{{ $config.lan_network_name }}" # Promiscuous mode or MAC Learning enabled, and VLAN trunking enabled
ssh_authorized_keys = [
{{- range $value := $config.authorized_keys }}
  "{{ $value }}",
{{- end }}
]

external_network = {
  name        = "{{ $config.wan_network_name }}"
  subnet_mask = "{{ $config.wan_subnet_mask }}"
  gateway     = "{{ $config.wan_gateway }}"
  nameservers = [
{{- range $dns_server := $config.wan_dns_servers }}
  "{{ $dns_server }}",
{{- end }}
  ]
  ntp         = "{{ $config.wan_ntp }}"
  ip          = "{{ $config.router_wan_ip}}" # gateway to lab network. using dhcp if "" is provided
}

esxi_iso_datastore = "{{ $config.esxi_iso_datastore }}"
esxi_iso_path      = "{{ $config.esxi_iso_path }}"

nested_vcsa = {
  self_managed      = true
  ip                = "10.0.0.100"
  hostname          = "vcsa01"
  remote_ovf_url    = ""
  iso_path          = "{{ $config.vcsa_iso_path }}"
  iso_datastore     = "{{ $config.vcsa_iso_datastore }}"
  datastore         = "iscsi01"
  deployment_option = "{{ $config.vcsa_deployment_option }}"
}

photon_ovf_url = "{{ $config.photon_ovf_url }}"
ubuntu_ovf_url = "{{ $config.ubuntu_ovf_url }}"

nested_esxi_count = {{ $config.esxi_count }}
nested_esxi_shape = {
  "num_cpus"     = {{ $config.esxi_cpus }}
  "mem_gb"       = {{ $config.esxi_mem_gb }}
  "nic_count"    = 8
  "tpm_enabled"  = {{ $config.esxi_with_tpm }}
  "nvme_enabled" = false
  "disks" = [
    {
      "label"       = "disk0"
      "size_gb"     = "{{ $config.esxi_disk0_size_gb }}"
      "unit_number" = 0
    }
  ]
}

nameservers         = ["10.0.0.1"]
subnet_mask         = "255.255.255.0"
gateway             = "10.0.0.1"
ntp                 = "10.0.0.1"
domain_name         = "{{ $config.nested_domain_name }}"

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
provision_datastores = [
  {
    datastore_name = "iscsi01"
    path_name      = "vmhba65:C0:T0:L0"
  },
  {
    datastore_name = "iscsi02"
    path_name      = "vmhba65:C0:T0:L1"
  }
]

storage = {
  storage1_vlan = 1004
  storage2_vlan = 1005
  mtu           = 1500
  subnet_mask   = "255.255.255.0"
  disk_size_gb  = {{ $config.disk_size_gb }}
  lun_size_gb   = {{ $config.lun_size_gb }}
  lun_count     = 5
  storage1_ip   = "10.0.4.10"
  storage2_ip   = "10.0.5.10"
  ip            = "10.0.0.10"
}

vsphere_provisioner = {
  datacenter_name = "Datacenter"
  cluster_name    = "Cluster"
  ha_enabled      = true
  drs_enabled     = true
  vsan_enabled    = false # auto reclaim should not work
  storage_policy_list = [
    {
      name      = "wcp"
      datastore = "iscsi02"
    }
  ]
  content_library_list = [
    {
      name      = "lib01"
      datastore = "iscsi02"
    }
  ]
  dvs_list = [
    {
      name    = "DSwitch"
      version = "7.0.0"
      mtu     = "1500"
      uplinks = ["vmnic4", "vmnic5"]
      portgroups = [
        {
          name    = "vsan"
          vlan_id = "1002"
          vmknics = [
            {
              name        = "vmk3"
              starting_ip = "10.0.2.101"
              subnet_mask = "255.255.255.0"
              mtu         = "1500"
              enable_vsan = "True"
            }
          ]
        },
        {
          name    = "vmotion"
          vlan_id = "1003"
          vmknics = [
            {
              name           = "vmk4"
              starting_ip    = "10.0.3.101"
              subnet_mask    = "255.255.255.0"
              mtu            = "1500"
              enable_vmotion = "True"
            }
          ]
        },
        {
          name    = "frontend"
          vlan_id = "1006"
          vmknics = []
        },
        {
          name    = "workload"
          vlan_id = "1007"
          vmknics = []
        }
      ]
    },
    {
      name       = "nsx"
      version    = "7.0.0"
      mtu        = "1700"
      uplinks    = ["vmnic6", "vmnic7"]
      portgroups = []
    }
  ]
}
