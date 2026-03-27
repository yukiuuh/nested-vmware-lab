locals {
  deployment_name_prefix = "${var.name_prefix}-${random_id.deployment.hex}"

  provider = {
    server           = try(var.provider_config.server, null)
    user             = try(var.provider_config.user, null)
    password         = try(var.provider_config.password, null)
    datacenter       = var.provider_config.datacenter
    resource_pool    = var.provider_config.resource_pool
    compute_host     = var.provider_config.compute_host
    datastore        = var.provider_config.datastore
    default_networks = try(var.provider_config.default_networks, {})
  }

  install_sources     = var.install_sources
  routers             = var.routers
  esxi_groups         = var.esxi_groups
  storages            = var.storages
  ssh_authorized_keys = var.ssh_authorized_keys
  vcenters            = var.vcenters
  services            = var.services

  supported_router_source_types = toset([
    "http_ovf",
    "local_ovf",
  ])

  supported_router_placements = toset([
    "provider_vsphere",
  ])

  supported_esxi_group_placements = toset([
    "provider_vsphere",
  ])

  supported_storage_source_types = toset([
    "http_ovf",
    "local_ovf",
  ])

  supported_storage_placements = toset([
    "provider_vsphere",
  ])

  supported_esxi_install_methods = toset([
    "ansible_router_pxe",
    "ansible_vsphere_iso_boot",
  ])

  supported_esxi_kickstart_templates = toset([
    "esxi-8.0",
  ])

  supported_esxi_install_source_types = toset([
    "http_iso",
    "rclone_iso",
    "datastore_iso",
  ])

  router_source_refs = {
    for name, router in local.routers :
    name => coalesce(
      try(router.source.install_source, null),
      try(router.template, null)
    )
  }

  storage_source_refs = {
    for name, storage in local.storages :
    name => coalesce(
      try(storage.source.install_source, null),
      try(storage.template, null)
    )
  }

  router_service_flags = {
    for name, router in local.routers :
    name => {
      pxe    = try(router.execution.enable_pxe, true)
      http   = try(router.execution.enable_http, true)
      rclone = try(router.execution.enable_rclone, false)
    }
  }

  router_runtime_paths = {
    for name, router in local.routers :
    name => {
      http_root = trimsuffix(try(router.execution.http_root, "/var/www/html"), "/")
      tftp_root = trimsuffix(try(router.execution.tftp_root, "/srv/tftp"), "/")
    }
  }

  router_ansible = {
    for name, _ in local.routers :
    name => {
      user = "labadmin"
    }
  }

  router_management_networks = {
    for name, router in local.routers :
    name => cidrsubnet("${router.networks.lan.network}/16", 8, 0)
  }

  router_management_ips = {
    for name, network in local.router_management_networks :
    name => cidrhost(network, 1)
  }

  all_networks = toset(compact(distinct(concat(
    values(local.provider.default_networks),
    flatten([
      for _, router in local.routers : [
        try(router.networks.wan.network_name, null),
        try(router.networks.lan.network_name, null),
      ]
    ]),
    flatten([
      for _, group in local.esxi_groups : [
        try(group.placement.network, null),
      ]
    ])
  ))))

  esxi_group_networks = {
    for name, group in local.esxi_groups :
    name => coalesce(
      try(group.placement.network, null),
      try(local.routers[group.router].networks.lan.network_name, null),
      try(local.provider.default_networks.lan, null)
    )
  }

  esxi_group_defaults = {
    for name, group in local.esxi_groups :
    name => {
      router_domain_name = try(local.routers[group.router].networks.lan.domain_name, null)
      router_gateway     = try(cidrhost("${local.routers[group.router].networks.lan.network}/24", 1), null)
    }
    if contains(keys(local.routers), group.router)
  }

  storage_defaults = {
    for name, storage in local.storages :
    name => {
      router_domain_name = try(local.routers[storage.router].networks.lan.domain_name, null)
      router_gateway     = try(cidrhost("${local.routers[storage.router].networks.lan.network}/24", 1), null)
      network_name = coalesce(
        try(storage.placement.network, null),
        try(local.routers[storage.router].networks.lan.network_name, null),
        try(local.provider.default_networks.lan, null)
      )
    }
    if contains(keys(local.routers), try(storage.router, ""))
  }

  esxi_group_hosts = merge([
    for name, group in local.esxi_groups : {
      for idx in range(group.count) : "${name}/${idx}" => {
        group_name    = name
        index         = idx
        ip_prefix     = join(".", slice(split(".", group.starting_ip), 0, 3))
        starting_host = tonumber(element(split(".", group.starting_ip), 3))
        hostname      = format("%s%02d", group.hostname_prefix, idx + 1)
        ip            = format("%s.%d", join(".", slice(split(".", group.starting_ip), 0, 3)), tonumber(element(split(".", group.starting_ip), 3)) + idx)
        fqdn = format(
          "%s%02d.%s",
          group.hostname_prefix,
          idx + 1,
          coalesce(
            try(group.domain_name, null),
            try(local.esxi_group_defaults[name].router_domain_name, null),
            "localdomain"
          )
        )
      }
    }
  ]...)

  esxi_group_runtime = {
    for name, group in local.esxi_groups :
    name => {
      name = name

      placement = {
        kind          = group.placement.kind
        datacenter    = local.provider.datacenter
        resource_pool = local.provider.resource_pool
        host          = local.provider.compute_host
        datastore     = local.provider.datastore
        network       = local.esxi_group_networks[name]
      }

      router = group.router
      count  = group.count
      hosts = [
        for idx in range(group.count) : {
          key      = "${name}/${idx}"
          index    = idx
          name     = local.esxi_group_hosts["${name}/${idx}"].hostname
          vm_name  = local.esxi_group_hosts["${name}/${idx}"].hostname
          hostname = local.esxi_group_hosts["${name}/${idx}"].hostname
          fqdn     = local.esxi_group_hosts["${name}/${idx}"].fqdn
          ip       = local.esxi_group_hosts["${name}/${idx}"].ip
        }
      ]

      network = {
        network_name = local.esxi_group_networks[name]
        domain_name = coalesce(
          try(group.domain_name, null),
          try(local.esxi_group_defaults[name].router_domain_name, null)
        )
        gateway = coalesce(
          try(group.gateway, null),
          try(local.esxi_group_defaults[name].router_gateway, null)
        )
        nameservers = coalesce(
          try(group.nameservers, null),
          try([local.esxi_group_defaults[name].router_gateway], null),
          []
        )
        subnet_mask = try(group.subnet_mask, "255.255.255.0")
      }

      ntp_servers = try(group.ntp_servers, [])

      shape = group.shape
      install = {
        method         = group.install.method
        install_source = group.install.source.install_source
        kickstart      = try(group.install.kickstart, null)
        source         = local.install_sources[group.install.source.install_source]
        boot_mode = (
          group.install.method == "ansible_router_pxe" ? "pxe" : "cdrom"
        )
      }
      managed_by = try(group.managed_by, [])
    }
    if contains(keys(local.routers), group.router)
    && local.esxi_group_networks[name] != null
    && contains(local.supported_esxi_group_placements, try(group.placement.kind, ""))
    && contains(local.supported_esxi_install_methods, try(group.install.method, ""))
    && contains(keys(local.install_sources), try(group.install.source.install_source, ""))
    && contains(local.supported_esxi_install_source_types, try(local.install_sources[group.install.source.install_source].type, ""))
  }

  storage_runtime = {
    for name, storage in local.storages :
    name => {
      name = "${local.deployment_name_prefix}-${name}"

      placement = {
        kind          = storage.placement.kind
        datacenter    = local.provider.datacenter
        resource_pool = local.provider.resource_pool
        host          = local.provider.compute_host
        datastore     = local.provider.datastore
        network       = local.storage_defaults[name].network_name
      }

      router = storage.router
      network = {
        network_name = local.storage_defaults[name].network_name
        domain_name = coalesce(
          try(storage.domain_name, null),
          try(local.storage_defaults[name].router_domain_name, null)
        )
        gateway = coalesce(
          try(storage.gateway, null),
          try(local.storage_defaults[name].router_gateway, null)
        )
        nameservers = coalesce(
          try(storage.nameservers, null),
          try([local.storage_defaults[name].router_gateway], null),
          []
        )
        subnet_mask = try(storage.subnet_mask, "255.255.255.0")
      }
      source_ref     = local.storage_source_refs[name]
      install_source = local.install_sources[local.storage_source_refs[name]]
      shape = {
        num_cpus = try(storage.num_cpus, 4)
        mem_gb   = try(storage.mem_gb, 4)
      }
      service = {
        ip                   = storage.ip
        storage1_ip          = storage.storage1_ip
        storage2_ip          = storage.storage2_ip
        storage1_vlan        = storage.storage1_vlan
        storage2_vlan        = storage.storage2_vlan
        storage_mtu          = storage.mtu
        storage_subnet_mask  = storage.storage_subnet_mask
        storage_disk_size_gb = storage.disk_size_gb
        luns                 = try(storage.luns, [])
        zfs_compression      = try(storage.zfs_compression, "off")
        zfs_nfs_dedup        = try(storage.zfs_nfs_dedup, "off")
      }
      ansible = {
        user = "labadmin"
      }
    }
    if contains(keys(local.routers), try(storage.router, ""))
    && contains(keys(local.storage_defaults), name)
    && local.storage_source_refs[name] != null
    && contains(keys(local.install_sources), local.storage_source_refs[name])
    && contains(local.supported_storage_source_types, try(local.install_sources[local.storage_source_refs[name]].type, ""))
    && contains(local.supported_storage_placements, try(storage.placement.kind, ""))
    && local.storage_defaults[name].network_name != null
  }

  router_runtime = {
    for name, router in local.routers :
    name => {
      name = "${local.deployment_name_prefix}-${name}"

      placement = {
        kind          = router.placement.kind
        datacenter    = local.provider.datacenter
        resource_pool = local.provider.resource_pool
        host          = local.provider.compute_host
        datastore     = local.provider.datastore
        network       = router.networks.lan.network_name
      }

      networks       = router.networks
      install_source = local.install_sources[local.router_source_refs[name]]
      services       = local.router_service_flags[name]
      runtime        = local.router_runtime_paths[name]
      ansible        = local.router_ansible[name]
    }
    if local.router_source_refs[name] != null
    && contains(keys(local.install_sources), local.router_source_refs[name])
    && contains(local.supported_router_source_types, local.install_sources[local.router_source_refs[name]].type)
    && contains(local.supported_router_placements, try(router.placement.kind, ""))
  }

  esxi_host_execution = {
    for host_key, host in local.esxi_group_hosts :
    host_key => {
      group_name           = host.group_name
      hostname             = host.hostname
      fqdn                 = host.fqdn
      ip                   = host.ip
      vm_name              = format("%s-%s-%s", local.deployment_name_prefix, host.group_name, host.hostname)
      router               = local.esxi_group_runtime[host.group_name].router
      router_name          = local.router_runtime[local.esxi_group_runtime[host.group_name].router].name
      router_management_ip = local.router_management_ips[local.esxi_group_runtime[host.group_name].router]
      router_services      = local.router_service_flags[local.esxi_group_runtime[host.group_name].router]
      router_runtime       = local.router_runtime_paths[local.esxi_group_runtime[host.group_name].router]
      router_ansible       = local.router_ansible[local.esxi_group_runtime[host.group_name].router]
      network              = local.esxi_group_runtime[host.group_name].network
      install_method       = local.esxi_group_runtime[host.group_name].install.method
      install_source_ref   = local.esxi_group_runtime[host.group_name].install.install_source
      install_source       = local.esxi_group_runtime[host.group_name].install.source
      pxe = {
        kickstart_template = try(local.esxi_group_runtime[host.group_name].install.kickstart.template, null)
        kickstart_url = format(
          "http://%s/kickstart/%s/%s/%s.cfg",
          local.router_management_ips[local.esxi_group_runtime[host.group_name].router],
          local.esxi_group_runtime[host.group_name].install.install_source,
          host.group_name,
          host.hostname
        )
        boot_kernel_options = join("", compact([
          format(" ks=%s", format(
            "http://%s/kickstart/%s/%s/%s.cfg",
            local.router_management_ips[local.esxi_group_runtime[host.group_name].router],
            local.esxi_group_runtime[host.group_name].install.install_source,
            host.group_name,
            host.hostname
          )),
          try(length(local.esxi_group_runtime[host.group_name].network.nameservers), 0) > 0 ? format(" nameserver=%s", local.esxi_group_runtime[host.group_name].network.nameservers[0]) : "",
          format(" ip=%s", host.ip),
          format(" netmask=%s", local.esxi_group_runtime[host.group_name].network.subnet_mask),
          format(" gateway=%s", local.esxi_group_runtime[host.group_name].network.gateway),
          format(
            " entropySources=%d",
            try(local.esxi_group_runtime[host.group_name].shape.hardware_random_generator_enabled, true) ? 0 : 1
          ),
          format(
            " disableHwrng=%s",
            try(local.esxi_group_runtime[host.group_name].shape.hardware_random_generator_enabled, true) ? "FALSE" : "TRUE"
          ),
          " allowLegacyCPU=true",
        ]))
      }
    }
    if contains(keys(local.esxi_group_runtime), host.group_name)
  }

  router_outputs = {
    for name, router in local.router_runtime :
    name => {
      name               = module.routers[name].name
      wan_ip             = module.routers[name].wan_ip
      management_network = module.routers[name].management_network
      management_ip      = local.router_management_ips[name]
      placement          = router.placement
      networks           = router.networks
      services           = router.services
      runtime            = router.runtime
      install_source     = local.router_source_refs[name]
      ansible            = merge(router.ansible, { host = module.routers[name].wan_ip })
    }
  }

  storage_outputs = {
    for name, storage in local.storage_runtime :
    name => {
      name      = module.storages[name].name
      ip        = module.storages[name].ip
      router    = storage.router
      placement = storage.placement
      network   = storage.network
      service   = storage.service
      ansible   = merge(storage.ansible, { host = module.storages[name].ip })
      hostname  = "storage"
      fqdn = storage.network.domain_name != null ? format(
        "storage.%s",
        storage.network.domain_name
      ) : null
      install_source = storage.source_ref
    }
  }

  esxi_group_outputs = {
    for name, group in local.esxi_group_runtime :
    name => {
      placement   = group.placement
      router      = group.router
      network     = group.network
      ntp_servers = group.ntp_servers
      install     = group.install
      managed_by  = group.managed_by
      hosts = [
        for host in group.hosts : merge({
          name                = module.esxi_hosts[host.key].name
          hostname            = host.hostname
          fqdn                = host.fqdn
          ip                  = host.ip
          mac_addresses       = module.esxi_hosts[host.key].mac_addresses
          primary_mac_address = module.esxi_hosts[host.key].primary_mac_address
          group               = name
          ansible = {
            host = host.ip
            user = "root"
          }
          pxe = {
            router               = local.esxi_host_execution[host.key].router
            router_name          = local.esxi_host_execution[host.key].router_name
            router_management_ip = local.esxi_host_execution[host.key].router_management_ip
            kickstart_url        = local.esxi_host_execution[host.key].pxe.kickstart_url
            kickstart_template   = local.esxi_host_execution[host.key].pxe.kickstart_template
            boot_kernel_options  = local.esxi_host_execution[host.key].pxe.boot_kernel_options
            install_source       = local.esxi_host_execution[host.key].install_source
            install_source_ref   = local.esxi_host_execution[host.key].install_source_ref
            install_method       = local.esxi_host_execution[host.key].install_method
            router_services      = local.esxi_host_execution[host.key].router_services
            router_runtime       = local.esxi_host_execution[host.key].router_runtime
            router_ansible       = merge(local.esxi_host_execution[host.key].router_ansible, { host = local.router_outputs[local.esxi_host_execution[host.key].router].ansible.host })
          }
        }, {})
      ]
    }
  }
}
