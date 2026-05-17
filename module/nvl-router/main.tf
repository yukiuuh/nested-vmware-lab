terraform {
  required_providers {
    vsphere = {
      source = "vmware/vsphere"
    }
  }
}

module "wan_address" {
  source     = "../common/netmask2prefix"
  ip_address = var.ip
  netmask    = var.subnet_mask
}


module "management_address" {
  source     = "../common/netmask2prefix"
  ip_address = var.ip
  netmask    = "255.255.255.0"
}
locals {
  nested_network_address = "${var.nested_network.network}/16"
  router_hostname        = "router"
  router_user            = "labadmin"

  evpn_enabled                = var.evpn.enabled
  evpn_underlay_vlan          = var.evpn.underlay.vlan
  evpn_underlay_vlan_offset   = local.evpn_underlay_vlan - var.nested_network.vlan_starts_with
  evpn_underlay_network_index = local.evpn_underlay_vlan_offset + 1
  evpn_underlay_network       = local.evpn_underlay_vlan_offset >= 0 && local.evpn_underlay_vlan_offset < var.nested_network.vlan_network_count ? cidrsubnet(local.nested_network_address, 8, local.evpn_underlay_network_index) : null
  evpn_underlay_address       = var.evpn.underlay.address != null ? var.evpn.underlay.address : (local.evpn_underlay_network != null ? "${cidrhost(local.evpn_underlay_network, 1)}/24" : null)
  evpn_vtep_ip                = local.evpn_underlay_address != null ? split("/", local.evpn_underlay_address)[0] : null
  evpn_underlay_mtu           = var.evpn.underlay.mtu
  lan_mtu                     = local.evpn_enabled ? max(var.nested_network.mtu, local.evpn_underlay_mtu) : var.nested_network.mtu
  evpn_router_asn             = var.evpn.bgp.router_asn
  evpn_route_controller_asn   = var.evpn.bgp.route_controller_asn
  evpn_route_controller_peers = distinct(compact(
    length(var.evpn.bgp.route_controller_peers) > 0
    ? var.evpn.bgp.route_controller_peers
    : [var.evpn.bgp.route_controller_ip]
  ))
  evpn_route_controller_ip     = try(local.evpn_route_controller_peers[0], null)
  evpn_route_controller_maxhop = var.evpn.bgp.route_controller_max_hop
  evpn_tenant_l3_vnis          = [for _, tenant in var.evpn.tenants : tenant.l3_vni]
  evpn_tenants = {
    for name, tenant in var.evpn.tenants : name => {
      vrf_name = coalesce(try(tenant.vrf_name, null), substr(replace(lower(name), "/[^a-z0-9_.-]/", "-"), 0, 15))
      vrf_table = coalesce(
        try(tenant.vrf_table, null),
        tenant.l3_vni
      )
      l3_vni = tenant.l3_vni
      rd = coalesce(
        try(tenant.rd, null),
        "${local.evpn_vtep_ip != null ? local.evpn_vtep_ip : "0.0.0.0"}:${tenant.l3_vni}"
      )
      import_rt = coalesce(
        try(tenant.import_rt, null),
        "${local.evpn_router_asn}:${tenant.l3_vni}"
      )
      export_rt = coalesce(
        try(tenant.export_rt, null),
        "${local.evpn_router_asn}:${tenant.l3_vni}"
      )
      test_cidr = try(tenant.test_cidr, null)
      test_gateway_cidr = coalesce(
        try(tenant.test_gateway_cidr, null),
        try("${cidrhost(tenant.test_cidr, 1)}/${split("/", tenant.test_cidr)[1]}", null)
      )
      bridge_interface = coalesce(
        try(tenant.bridge_interface, null),
        "br${tenant.l3_vni}"
      )
      vxlan_interface = coalesce(
        try(tenant.vxlan_interface, null),
        "vni${tenant.l3_vni}"
      )
      test_interface = coalesce(
        try(tenant.test_interface, null),
        substr("t-${replace(lower(name), "/[^a-z0-9_.-]/", "-")}", 0, 15)
      )
    }
  }
  evpn_setup = local.evpn_enabled && local.evpn_vtep_ip != null ? templatefile("${path.module}/templates/evpn-setup.sh.tftpl", {
    underlay_vlan = local.evpn_underlay_vlan
    mtu           = local.evpn_underlay_mtu
    vtep_ip       = local.evpn_vtep_ip
    tenants       = local.evpn_tenants
  }) : ""
  evpn_output = {
    enabled = local.evpn_enabled
    underlay = {
      vlan    = local.evpn_underlay_vlan
      network = local.evpn_underlay_network
      address = local.evpn_underlay_address
      mtu     = local.evpn_underlay_mtu
    }
    bgp = {
      router_asn               = local.evpn_router_asn
      route_controller_asn     = local.evpn_route_controller_asn
      route_controller_ip      = local.evpn_route_controller_ip
      route_controller_peers   = local.evpn_route_controller_peers
      route_controller_max_hop = local.evpn_route_controller_maxhop
      update_source            = var.evpn.bgp.update_source
    }
    tenants = local.evpn_tenants
  }

  management_network_address    = cidrsubnet(local.nested_network_address, 8, 0)
  vm_management_network_address = cidrsubnet(local.nested_network_address, 8, 1)
  vlan_networks = {
    for i in range(var.nested_network.vlan_network_count) : i => {
      "vlan"    = var.nested_network.vlan_starts_with + i
      "address" = cidrsubnet(local.nested_network_address, 8, i + 1)
      "mtu"     = local.evpn_enabled && var.nested_network.vlan_starts_with + i == local.evpn_underlay_vlan ? local.evpn_underlay_mtu : var.nested_network.mtu
    }
  }

  enable_dhcp_networks = {
    for i in range(var.nested_network.vlan_network_count) : i => {
      "vlan"     = var.nested_network.vlan_starts_with + i
      "network"  = cidrhost(cidrsubnet(local.nested_network_address, 8, i + 1), 0)
      "netmask"  = "255.255.255.0"
      "gateway"  = cidrhost(cidrsubnet(local.nested_network_address, 8, i + 1), 1)
      "start_ip" = cidrhost(cidrsubnet(local.nested_network_address, 8, i + 1), 200)
      "end_ip"   = cidrhost(cidrsubnet(local.nested_network_address, 8, i + 1), 250)
    }
  }

  frr_conf = templatefile("${path.module}/templates/frr.conf.tftpl", {
    management_network_address          = local.management_network_address
    router_asn                          = local.evpn_router_asn
    remote_asn1                         = "300"
    remote_asn2                         = "400"
    bgp_network1_address                = cidrsubnet(local.nested_network_address, 8, 10)
    bgp_network2_address                = cidrsubnet(local.nested_network_address, 8, 11)
    bgp_network3_address                = cidrsubnet(local.nested_network_address, 8, 12)
    bgp_network4_address                = cidrsubnet(local.nested_network_address, 8, 13)
    evpn_enabled                        = local.evpn_enabled
    evpn_vtep_ip                        = local.evpn_vtep_ip != null ? local.evpn_vtep_ip : "0.0.0.0"
    evpn_route_controller_peers         = local.evpn_route_controller_peers
    evpn_route_controller_asn           = local.evpn_route_controller_asn
    evpn_route_controller_maxhop        = local.evpn_route_controller_maxhop
    evpn_route_controller_password      = var.evpn.bgp.route_controller_password
    evpn_route_controller_update_source = var.evpn.bgp.update_source
    evpn_tenants                        = local.evpn_tenants
  })

  router_userdata = templatefile("${path.module}/templates/userdata.tftpl",
    {
      ssh_authorized_keys        = var.ssh_authorized_keys
      password                   = var.vm_password
      user                       = local.router_user
      vlan_networks              = local.vlan_networks
      management_network_address = local.management_network_address
      ip_address                 = var.ip
      subnet_mask                = module.management_address.prefix_length
      gateway                    = var.gateway
      nameservers                = var.nameservers
      domain                     = var.nested_network.domain_name
      hostname                   = local.router_hostname
      lan_mtu                    = local.lan_mtu
      http_proxy_port            = var.http_proxy_port
      enable_dhcp_networks       = local.enable_dhcp_networks
      frr_conf_base64            = base64encode(local.frr_conf)
      evpn_enabled               = local.evpn_enabled
      evpn_setup_base64          = base64encode(local.evpn_setup)
      hosts_base64 = base64encode(templatefile("${path.module}/templates/hosts.tftpl",
        {
          management_network_address    = local.management_network_address
          vm_management_network_address = local.vm_management_network_address
          domain                        = var.nested_network.domain_name
          hostname                      = local.router_hostname
        }
      ))
    }
  )
}

resource "terraform_data" "validate_evpn" {
  input = {
    enabled       = local.evpn_enabled
    underlay_vlan = local.evpn_underlay_vlan
    tenants       = keys(local.evpn_tenants)
  }

  lifecycle {
    precondition {
      condition     = !local.evpn_enabled || (local.evpn_underlay_vlan_offset >= 0 && local.evpn_underlay_vlan_offset < var.nested_network.vlan_network_count)
      error_message = "EVPN underlay VLAN ${local.evpn_underlay_vlan} must be within the Router LAN VLAN range."
    }

    precondition {
      condition     = !local.evpn_enabled || length(local.evpn_tenants) > 0
      error_message = "EVPN requires at least one tenant VRF."
    }

    precondition {
      condition     = !local.evpn_enabled || length(local.evpn_route_controller_peers) > 0
      error_message = "EVPN requires at least one Route Controller peer."
    }

    precondition {
      condition     = !local.evpn_enabled || length(distinct(local.evpn_tenant_l3_vnis)) == length(local.evpn_tenant_l3_vnis)
      error_message = "EVPN tenant l3_vni values must be unique."
    }
  }
}

module "router" {
  depends_on = [terraform_data.validate_evpn]

  source             = "../common/ubuntu"
  vi                 = var.vi
  name               = var.name
  remote_ovf_url     = var.ubuntu_ovf_url
  local_ovf_path     = var.local_ovf_path
  userdata           = local.router_userdata
  network_interfaces = [var.wan_network_name, var.network_name]
  cdroms             = var.cdroms
  num_cpus           = 2
  mem_gb             = 1
  disks = [
    {
      "label"       = "disk0"
      "size_gb"     = 10
      "unit_number" = 0
    }
  ]
}

resource "terraform_data" "wait_for_router" {
  depends_on = [module.router]
  input = {
    name     = var.name
    password = var.vm_password
    username = local.router_user
  }
  provisioner "local-exec" {
    command = "until govc guest.ls -l '${self.input.username}:${self.input.password}' -vm ${self.input.name} /var/tmp/provisioned ; do sleep 60 ; done"
    environment = merge(
      {
        GOVC_INSECURE   = "true"
        GOVC_DATACENTER = var.vi.datacenter.name
      },
      var.vi.govc_url != null ? {
        GOVC_URL = var.vi.govc_url
      } : {}
    )
  }
}
