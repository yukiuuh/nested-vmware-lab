variable "gateway" { type = string }
variable "nameservers" { type = list(string) }
variable "subnet_mask" {
  type    = string
  default = "255.255.255.0"
}
variable "ubuntu_ovf_url" { default = null }
variable "local_ovf_path" { default = null }
variable "vm_password" { default = "VMware123!" }

variable "wan_network_name" { type = string }
variable "network_name" { type = string }

variable "name" {}
variable "ip" {
  nullable = true
  type     = string
}
variable "vi" {}

variable "nested_network" {
  type = object({
    domain_name        = string
    network            = string
    mtu                = number
    vlan_starts_with   = number
    vlan_network_count = number
  })
}
variable "ssh_authorized_keys" {
  default = []
  type    = list(string)
}

variable "cdroms" {
  type = list(object({
    datastore_id = string
    path         = string
  }))
  default = []
}

variable "http_proxy_port" {
  default  = 8080
  type     = number
  nullable = false
}

variable "evpn" {
  description = "EVPN-VXLAN gateway settings. Enabled by default for Route Controller and tenant VRF testing."
  type = object({
    enabled = optional(bool, true)
    underlay = optional(object({
      vlan    = optional(number, 1014)
      address = optional(string)
      mtu     = optional(number, 8000)
    }), {})
    bgp = optional(object({
      router_asn                = optional(number, 200)
      route_controller_asn      = optional(number, 500)
      route_controller_ip       = optional(string, "10.0.10.10")
      route_controller_peers    = optional(list(string), [])
      route_controller_max_hop  = optional(number, 1)
      route_controller_password = optional(string)
      update_source             = optional(string)
    }), {})
    tenants = optional(map(object({
      vrf_name          = optional(string)
      vrf_table         = optional(number)
      l3_vni            = number
      rd                = optional(string)
      import_rt         = optional(string)
      export_rt         = optional(string)
      test_cidr         = optional(string)
      test_gateway_cidr = optional(string)
      bridge_interface  = optional(string)
      vxlan_interface   = optional(string)
      test_interface    = optional(string)
      })), {
      red = {
        l3_vni    = 50001
        test_cidr = "172.16.10.0/24"
      }
      blue = {
        l3_vni    = 50002
        test_cidr = "172.16.20.0/24"
      }
    })
  })
  default  = {}
  nullable = false
}
