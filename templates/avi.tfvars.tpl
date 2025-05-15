{{- $config := datasource "config" -}}

avi = {
  controller_ova_url = "{{ $config.avi_ova_url }}"
  license            = ""
  password           = "VMware123!"
  default_password   = "58NFaGDJm(PJH0G"
  gateway            = "10.0.6.1"
  controllers = [
    {
      hostname = "avi01"
      ip       = "10.0.0.89"
    }
  ]
  ipam_usable_networks = ["frontend"]
  networks = [
    {
      name     = "workload"
      network  = "10.0.7.0/24"
      begin_ip = "10.0.7.128"
      end_ip   = "10.0.7.191"
      type     = "STATIC_IPS_FOR_SE"
    },
    {
      name     = "frontend"
      network  = "10.0.6.0/24"
      begin_ip = "10.0.6.64"
      end_ip   = "10.0.6.191"
      type     = "STATIC_IPS_FOR_VIP_AND_SE"
    }
  ]
}
