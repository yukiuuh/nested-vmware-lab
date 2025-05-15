{{- $config := datasource "config" -}}

nsx = {
  manager_ova_path        = "{{ $config.nsx_manager_ova_path }}"
  manager_ova             = "{{ $config.nsx_manager_ova }}"
  license                 = "{{ $config.nsx_license }}"
  manager_deployment_size = "{{ $config.nsx_manager_deployment_size }}"
  password                = "VMware123!VMware123!"
  managers = [
    {
      hostname = "nsxm01"
      ip       = "10.0.0.81"
    }
  ]
  host_tep_ip_pool_gateway  = "10.0.8.1"
  host_tep_ip_pool_start_ip = "10.0.8.10"
  host_tep_ip_pool_end_ip   = "10.0.8.50"
  host_tep_ip_pool_cidr     = "10.0.8.0/24"
  host_tep_uplink_vlan      = 1008
  host_switch_name          = "nsx"
  host_switch_uplink_list = [
    {
      uplink_name     = "uplink-1"
      vds_uplink_name = "Uplink 1"
    }
  ]
  edge_deployment_size      = "{{ $config.nsx_edge_deployment_size }}"
  edge_tep_ip_pool_gateway  = "10.0.9.1"
  edge_tep_ip_pool_start_ip = "10.0.9.10"
  edge_tep_ip_pool_end_ip   = "10.0.9.50"
  edge_tep_ip_pool_cidr     = "10.0.9.0/24"
  edge_tep_uplink_vlan      = 1009
  # external_uplink_vlan_list = [1010, 1011]
  external_uplink_vlan = 1010
  t0_gateway           = "10.0.10.1"
  edge_vm_list = [
    {
      management_ip = "10.0.0.84"
      hostname      = "nsxe01"
      t0_interfaces = [
        {
          ip            = "10.0.10.84"
          prefix_length = "24"
        }
      ]
    }
  ]
}
