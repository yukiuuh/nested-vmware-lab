

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

  management_network_address = cidrsubnet(local.nested_network_address, 8, 0)
  vlan_networks = {
    for i in range(var.nested_network.vlan_network_count) : i => {
      "vlan"    = var.nested_network.vlan_starts_with + i
      "address" = cidrsubnet(local.nested_network_address, 8, i + 1)
    }
  }

  enable_dhcp_networks = {
    for i in range(var.nested_network.vlan_network_count) : i => {
      "network"  = cidrhost(cidrsubnet(local.nested_network_address, 8, i + 1), 0)
      "netmask"  = "255.255.255.0"
      "gateway"  = cidrhost(cidrsubnet(local.nested_network_address, 8, i + 1), 1)
      "start_ip" = cidrhost(cidrsubnet(local.nested_network_address, 8, i + 1), 200)
      "end_ip"   = cidrhost(cidrsubnet(local.nested_network_address, 8, i + 1), 250)
    }
  }

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
      vlan_mtu                   = var.nested_network.mtu
      http_proxy_port            = var.http_proxy_port
      enable_dhcp_networks       = local.enable_dhcp_networks
      hosts_base64 = base64encode(templatefile("${path.module}/templates/hosts.tftpl",
        {
          management_network_address = local.management_network_address
          domain                     = var.nested_network.domain_name
          hostname                   = local.router_hostname
        }
      ))
    }
  )
}


module "router" {
  source             = "../common/ubuntu"
  vi                 = var.vi
  name               = var.name
  remote_ovf_url     = var.ubuntu_ovf_url
  userdata           = local.router_userdata
  network_interfaces = [var.wan_network_name, var.network_name]
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
    environment = {
      GOVC_URL        = var.vi.govc_url
      GOVC_INSECURE   = "true"
      GOVC_DATACENTER = var.vi.datacenter.name
    }
  }
}
