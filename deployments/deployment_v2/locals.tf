locals {
  deployment_name_prefix = "${var.name_prefix}-${random_id.deployment.hex}"

  provider = {
    server           = try(var.provider_config.server, null)
    server_env       = try(var.provider_config.server_env, null)
    user             = try(var.provider_config.user, null)
    user_env         = try(var.provider_config.user_env, null)
    password         = try(var.provider_config.password, null)
    password_env     = try(var.provider_config.password_env, null)
    datacenter       = var.provider_config.datacenter
    datacenter_env   = try(var.provider_config.datacenter_env, null)
    resource_pool    = var.provider_config.resource_pool
    compute_host     = var.provider_config.compute_host
    datastore        = var.provider_config.datastore
    default_networks = try(var.provider_config.default_networks, {})
    insecure         = try(var.provider_config.insecure, true)
  }

  install_sources = {
    for name, source in var.install_sources :
    name => merge(
      source,
      try(source.type, "") == "datastore_iso" ? {
        path = coalesce(try(source.path, null), try(source.url, null))
      } : {}
    )
  }
  routers             = var.routers
  esxi_groups         = var.esxi_groups
  storages            = var.storages
  ssh_authorized_keys = var.ssh_authorized_keys
  ansible_connection = {
    user                 = try(var.ansible_connection.user, null)
    password             = try(var.ansible_connection.password, null)
    password_env         = try(var.ansible_connection.password_env, null)
    private_key_file     = try(var.ansible_connection.private_key_file, null)
    private_key_file_env = try(var.ansible_connection.private_key_file_env, null)
    ssh_common_args      = try(var.ansible_connection.ssh_common_args, null)
  }
  vcenters = var.vcenters
  services = var.services

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

  supported_vcenter_source_types = toset([
    "http_iso",
    "rclone_iso",
    "datastore_iso",
  ])

  supported_vcenter_placements = toset([
    "provider_vsphere",
    "nested_vsphere",
  ])

  supported_vcenter_nested_storage_modes = toset([
    "existing_datastore",
    "iscsi_datastore",
    "vsan_bootstrap",
  ])

  supported_vmkernel_adapter_services = toset([
    "vmotion",
    "vsan",
  ])

  install_source_version_search_text = {
    for name, source in local.install_sources :
    name => lower(join(" ", compact([
      try(source.url, null) != null ? basename(tostring(source.url)) : "",
      try(source.path, null) != null ? basename(tostring(source.path)) : "",
    ])))
  }

  install_source_semver_matches = {
    for name, text in local.install_source_version_search_text :
    name => regexall("([0-9]+)\\.([0-9]+)\\.([0-9]+)", text)
  }

  install_source_update_matches = {
    for name, text in local.install_source_version_search_text :
    name => regexall("([0-9]+)\\.([0-9]+)[._ -]*u([0-9]+)", text)
  }

  install_source_major_minor_matches = {
    for name, text in local.install_source_version_search_text :
    name => regexall("([0-9]+)\\.([0-9]+)", text)
  }

  install_source_vcenter_versions = {
    for name, source in local.install_sources :
    name => length(local.install_source_semver_matches[name]) > 0 ? {
      detected = true
      major    = tonumber(local.install_source_semver_matches[name][0][0])
      minor    = tonumber(local.install_source_semver_matches[name][0][1])
      patch    = tonumber(local.install_source_semver_matches[name][0][2])
      label    = join(".", local.install_source_semver_matches[name][0])
      } : length(local.install_source_update_matches[name]) > 0 ? {
      detected = true
      major    = tonumber(local.install_source_update_matches[name][0][0])
      minor    = tonumber(local.install_source_update_matches[name][0][1])
      patch    = tonumber(local.install_source_update_matches[name][0][2])
      label    = format("%s.%s U%s", local.install_source_update_matches[name][0][0], local.install_source_update_matches[name][0][1], local.install_source_update_matches[name][0][2])
      } : length(local.install_source_major_minor_matches[name]) > 0 ? {
      detected = true
      major    = tonumber(local.install_source_major_minor_matches[name][0][0])
      minor    = tonumber(local.install_source_major_minor_matches[name][0][1])
      patch    = 0
      label    = join(".", local.install_source_major_minor_matches[name][0])
      } : {
      detected = false
      major    = null
      minor    = null
      patch    = null
      label    = null
    }
  }

  install_source_supports_vsan_bootstrap = {
    for name, version in local.install_source_vcenter_versions :
    name => version.detected ? (
      version.major > 7
      || (
        version.major == 7
        && (
          version.minor > 0
          || (
            version.minor == 0
            && version.patch >= 2
          )
        )
      )
    ) : false
  }

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

  vcenter_source_refs = {
    for name, vcenter in local.vcenters :
    name => try(vcenter.source.install_source, null)
  }

  router_vcenter_datastore_iso_sources = {
    for name, _ in local.routers :
    name => sort(distinct([
      for vcenter_name, vcenter in local.vcenters :
      local.vcenter_source_refs[vcenter_name]
      if try(vcenter.router, "") == name
      && local.vcenter_source_refs[vcenter_name] != null
      && contains(keys(local.install_sources), local.vcenter_source_refs[vcenter_name])
      && try(local.install_sources[local.vcenter_source_refs[vcenter_name]].type, "") == "datastore_iso"
    ]))
  }

  router_datastore_iso_source_devices = {
    for name, sources in local.router_vcenter_datastore_iso_sources :
    name => {
      for idx, source_name in sources :
      source_name => {
        device_path = format("/dev/sr%d", idx)
        datastore   = try(local.install_sources[source_name].datastore, null)
        path        = try(local.install_sources[source_name].path, null)
      }
    }
  }

  router_service_flags = {
    for name, router in local.routers :
    name => {
      pxe = (
        try(router.execution.enable_pxe, false)
        || length([
          for _, group in local.esxi_groups : group
          if try(group.router, "") == name
          && try(group.install.method, "") == "ansible_router_pxe"
        ]) > 0
      )
      http = (
        try(router.execution.enable_http, false)
        || length([
          for _, group in local.esxi_groups : group
          if try(group.router, "") == name
        ]) > 0
      )
      rclone = (
        try(router.execution.enable_rclone, false)
        || length([
          for _, group in local.esxi_groups : group
          if try(group.router, "") == name
          && try(group.install.source.install_source, null) != null
          && contains(keys(local.install_sources), try(group.install.source.install_source, ""))
          && try(local.install_sources[group.install.source.install_source].type, "") == "rclone_iso"
        ]) > 0
        || length([
          for _, vcenter in local.vcenters : vcenter
          if try(vcenter.router, "") == name
          && try(vcenter.source.install_source, null) != null
          && contains(keys(local.install_sources), try(vcenter.source.install_source, ""))
          && try(local.install_sources[vcenter.source.install_source].type, "") == "rclone_iso"
        ]) > 0
      )
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
      user     = "labadmin"
      password = var.vm_admin_password
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

  vcenter_defaults = {
    for name, vcenter in local.vcenters :
    name => {
      router_domain_name = try(local.routers[vcenter.router].networks.lan.domain_name, null)
      router_gateway     = try(cidrhost("${local.routers[vcenter.router].networks.lan.network}/24", 1), null)
      network_name = coalesce(
        try(vcenter.placement.network, null),
        try(local.routers[vcenter.router].networks.lan.network_name, null),
        try(local.provider.default_networks.lan, null)
      )
    }
    if contains(keys(local.routers), try(vcenter.router, ""))
  }

  provider_vcenter_target_kind = (
    (
      local.provider.server != null
      && local.provider.compute_host != null
      && local.provider.server == local.provider.compute_host
    )
    || lower(coalesce(local.provider.user, "nvl-not-root")) == "root"
  ) ? "esxi" : "vc"

  vcenter_target_paths = {
    for name, vcenter in local.vcenters :
    name => compact(concat(
      try(vcenter.placement.cluster, null) != null ? [vcenter.placement.cluster] : [],
      try(vcenter.placement.resource_pool, null) != null ? ["Resources", vcenter.placement.resource_pool] : [],
      (
        try(vcenter.placement.cluster, null) == null
        && try(vcenter.placement.resource_pool, null) == null
      ) ? [coalesce(try(vcenter.placement.host, null), local.provider.compute_host)] : []
    ))
  }

  vcenter_nested_target_host_matches = {
    for name, vcenter in local.vcenters :
    name => [
      for host_key, host in local.esxi_group_hosts : merge(host, {
        key               = host_key
        vm_name           = format("%s-%s-%s", local.deployment_name_prefix, host.group_name, host.hostname)
        vmkernel_adapters = try(local.esxi_group_host_vmkernel_adapters[host_key], [])
      })
      if try(vcenter.placement.kind, "") == "nested_vsphere"
      && host.group_name == try(vcenter.placement.esxi_group, "")
      && contains(
        compact([
          try(host.hostname, null),
          try(host.fqdn, null),
          try(host.ip, null),
        ]),
        try(vcenter.placement.host, "")
      )
    ]
  }

  vcenter_nested_target_hosts = {
    for name, matches in local.vcenter_nested_target_host_matches :
    name => one(matches)
    if length(matches) == 1
  }

  storage_luns = merge(concat([{}], [
    for storage_name, storage in local.storages : {
      for idx, lun in try(storage.luns, []) : "${storage_name}/${lun.name}" => merge(lun, {
        storage = storage_name
        lun_id  = idx
      })
    }
  ])...)

  vcenter_nested_storage_modes = {
    for name, vcenter in local.vcenters :
    name => try(vcenter.placement.storage.mode, "existing_datastore")
    if try(vcenter.placement.kind, "") == "nested_vsphere"
  }

  vcenter_nested_storage_configs = {
    for name, vcenter in local.vcenters :
    name => {
      mode = local.vcenter_nested_storage_modes[name]
      iscsi = local.vcenter_nested_storage_modes[name] == "iscsi_datastore" ? {
        storage           = try(vcenter.placement.storage.storage, null)
        lun               = try(vcenter.placement.storage.lun, null)
        lun_id            = try(local.storage_luns["${vcenter.placement.storage.storage}/${vcenter.placement.storage.lun}"].lun_id, null)
        vmkernel_purposes = try(vcenter.placement.storage.vmkernel_purposes, [])
        port_binding      = try(vcenter.placement.storage.port_binding, false)
        vmkernel_adapters = [
          for adapter in try(local.vcenter_nested_target_hosts[name].vmkernel_adapters, []) : adapter
          if contains(try(vcenter.placement.storage.vmkernel_purposes, []), adapter.purpose)
        ]
        portals = distinct([
          for portal in compact(coalesce(
            try(vcenter.placement.storage.portals, null),
            try([
              local.storage_runtime[vcenter.placement.storage.storage].service.storage1_ip,
              local.storage_runtime[vcenter.placement.storage.storage].service.storage2_ip,
            ], null),
            []
          )) : can(regex(":[0-9]+$", portal)) ? portal : "${portal}:3260"
        ])
        size_gb = try(local.storage_luns["${vcenter.placement.storage.storage}/${vcenter.placement.storage.lun}"].size_gb, null)
      } : null
      vsan = local.vcenter_nested_storage_modes[name] == "vsan_bootstrap" ? {
        datastore_name                = coalesce(try(vcenter.placement.storage.vsan.datastore_name, null), try(vcenter.placement.datastore, null))
        datacenter                    = try(vcenter.placement.storage.vsan.datacenter, null)
        cluster                       = try(vcenter.placement.storage.vsan.cluster, null)
        cache_disks                   = try(vcenter.placement.storage.vsan.cache_disks, [])
        capacity_disks                = try(vcenter.placement.storage.vsan.capacity_disks, [])
        compression_only              = try(vcenter.placement.storage.vsan.compression_only, false)
        deduplication_and_compression = try(vcenter.placement.storage.vsan.deduplication_and_compression, false)
        enable_vlcm                   = try(vcenter.placement.storage.vsan.enable_vlcm, false)
      } : null
    }
    if try(vcenter.placement.kind, "") == "nested_vsphere"
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

  esxi_group_vmkernel_adapter_definitions = {
    for name, group in local.esxi_groups :
    name => [
      for adapter in try(group.vmkernel_adapters, []) : {
        name      = try(tostring(adapter.name), null)
        purpose   = try(tostring(adapter.purpose), null)
        vswitch   = try(tostring(adapter.vswitch), null)
        portgroup = try(tostring(adapter.portgroup), null)
        uplink    = try(tostring(adapter.uplink), null)
        active_uplinks = distinct(compact(concat(
          try(trimspace(tostring(adapter.uplink)), "") != "" ? [trimspace(tostring(adapter.uplink))] : [],
          try([for uplink in adapter.active_uplinks : trimspace(tostring(uplink))], [])
        )))
        standby_uplinks = distinct(compact(try([
          for uplink in adapter.standby_uplinks : trimspace(tostring(uplink))
        ], [])))
        unused_uplinks = distinct(compact(try([
          for uplink in adapter.unused_uplinks : trimspace(tostring(uplink))
        ], [])))
        uplinks = distinct(compact(concat(
          try(trimspace(tostring(adapter.uplink)), "") != "" ? [trimspace(tostring(adapter.uplink))] : [],
          try([for uplink in adapter.active_uplinks : trimspace(tostring(uplink))], []),
          try([for uplink in adapter.standby_uplinks : trimspace(tostring(uplink))], []),
          try([for uplink in adapter.unused_uplinks : trimspace(tostring(uplink))], [])
        )))
        vlan                      = try(tonumber(adapter.vlan), null)
        mtu                       = try(tonumber(adapter.mtu), try(tonumber(local.routers[group.router].networks.lan.mtu), null))
        subnet                    = try(tostring(adapter.subnet), null)
        subnet_mask               = try(cidrnetmask(adapter.subnet), null)
        ip                        = try(tostring(adapter.ip), null)
        ip_offset_from_management = coalesce(try(adapter.ip_offset_from_management, null), true)
        services = distinct(compact(concat(
          try([for service in adapter.services : lower(trimspace(tostring(service)))], []),
          contains(["vmotion", "vsan"], lower(trimspace(try(tostring(adapter.purpose), "")))) ? [lower(trimspace(tostring(adapter.purpose)))] : []
        )))
      }
    ]
  }

  esxi_group_host_vmkernel_adapters = {
    for host_key, host in local.esxi_group_hosts :
    host_key => [
      for adapter in try(local.esxi_group_vmkernel_adapter_definitions[host.group_name], []) : merge(adapter, {
        ip = (
          adapter.ip != null
          ? adapter.ip
          : (
            adapter.ip_offset_from_management
            ? try(cidrhost(adapter.subnet, tonumber(element(split(".", host.ip), 3))), null)
            : null
          )
        )
      })
    ]
  }

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
          vmkernel_adapters = try(
            local.esxi_group_host_vmkernel_adapters["${name}/${idx}"],
            []
          )
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
        luns = [
          for idx, lun in try(storage.luns, []) : merge(lun, {
            lun_id = idx
          })
        ]
        zfs_compression = try(storage.zfs_compression, "off")
        zfs_nfs_dedup   = try(storage.zfs_nfs_dedup, "off")
      }
      ansible = {
        user     = "labadmin"
        password = var.vm_admin_password
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

  vcenter_runtime = {
    for name, vcenter in local.vcenters :
    name => {
      name     = "${local.deployment_name_prefix}-${name}"
      router   = vcenter.router
      hostname = vcenter.hostname
      fqdn     = format("%s.%s", vcenter.hostname, coalesce(try(local.vcenter_defaults[name].router_domain_name, null), "localdomain"))
      ip       = vcenter.ip
      placement = {
        kind          = vcenter.placement.kind
        datacenter    = vcenter.placement.kind == "nested_vsphere" ? null : coalesce(try(vcenter.placement.datacenter, null), local.provider.datacenter)
        resource_pool = vcenter.placement.kind == "nested_vsphere" ? null : coalesce(try(vcenter.placement.resource_pool, null), local.provider.resource_pool)
        host          = vcenter.placement.kind == "nested_vsphere" ? try(vcenter.placement.host, null) : coalesce(try(vcenter.placement.host, null), local.provider.compute_host)
        datastore     = vcenter.placement.kind == "nested_vsphere" ? try(vcenter.placement.datastore, null) : coalesce(try(vcenter.placement.datastore, null), local.provider.datastore)
        network       = vcenter.placement.kind == "nested_vsphere" ? try(vcenter.placement.network, null) : local.vcenter_defaults[name].network_name
        esxi_group    = vcenter.placement.kind == "nested_vsphere" ? try(vcenter.placement.esxi_group, null) : null
        storage       = vcenter.placement.kind == "nested_vsphere" ? local.vcenter_nested_storage_configs[name] : null
      }
      network = {
        network_name = local.vcenter_defaults[name].network_name
        domain_name  = try(local.vcenter_defaults[name].router_domain_name, null)
        gateway      = try(local.vcenter_defaults[name].router_gateway, null)
        nameservers  = coalesce(try(vcenter.nameservers, null), try([local.vcenter_defaults[name].router_gateway], null), [])
        subnet_mask  = try(vcenter.subnet_mask, "255.255.255.0")
      }
      deployment_size = vcenter.deployment_size
      sso_domain_name = try(vcenter.sso_domain_name, "vsphere.local")
      manages         = try(vcenter.manages, [])
      depots          = try(vcenter.depots, [])
      ntp_servers = distinct(compact(concat(
        flatten([
          for managed_group in try(vcenter.manages, []) : try(local.esxi_groups[managed_group].ntp_servers, [])
        ]),
        try([local.vcenter_defaults[name].router_gateway], [])
      )))
      install = {
        install_source = local.vcenter_source_refs[name]
        source         = local.install_sources[local.vcenter_source_refs[name]]
        vcsa_version   = local.install_source_vcenter_versions[local.vcenter_source_refs[name]]
      }
      target = {
        kind = (
          vcenter.placement.kind == "nested_vsphere"
          ? "esxi"
          : local.provider_vcenter_target_kind
        )
        cluster = try(vcenter.placement.cluster, null)
        resource_pool = (
          vcenter.placement.kind == "nested_vsphere"
          ? null
          : coalesce(try(vcenter.placement.resource_pool, null), local.provider.resource_pool)
        )
        host = (
          vcenter.placement.kind == "nested_vsphere"
          ? try(vcenter.placement.host, null)
          : coalesce(try(vcenter.placement.host, null), local.provider.compute_host)
        )
        hostname = (
          vcenter.placement.kind == "nested_vsphere"
          ? try(local.vcenter_nested_target_hosts[name].fqdn, try(vcenter.placement.host, null))
          : (
            local.provider_vcenter_target_kind == "esxi"
            ? coalesce(try(vcenter.placement.host, null), local.provider.compute_host)
            : local.provider.server
          )
        )
        username = (
          vcenter.placement.kind == "nested_vsphere"
          ? "root"
          : local.provider.user
        )
        password = (
          vcenter.placement.kind == "nested_vsphere"
          ? var.vm_admin_password
          : local.provider.password
        )
        datacenter = (
          vcenter.placement.kind == "nested_vsphere"
          ? null
          : coalesce(try(vcenter.placement.datacenter, null), local.provider.datacenter)
        )
        datastore          = vcenter.placement.kind == "nested_vsphere" ? try(vcenter.placement.datastore, null) : coalesce(try(vcenter.placement.datastore, null), local.provider.datastore)
        deployment_network = vcenter.placement.kind == "nested_vsphere" ? try(vcenter.placement.network, null) : local.vcenter_defaults[name].network_name
        esxi_group         = vcenter.placement.kind == "nested_vsphere" ? try(vcenter.placement.esxi_group, null) : null
        storage            = vcenter.placement.kind == "nested_vsphere" ? local.vcenter_nested_storage_configs[name] : null
        esxi_host = (
          vcenter.placement.kind == "nested_vsphere"
          ? try(local.vcenter_nested_target_hosts[name], null)
          : null
        )
        target = (
          local.provider_vcenter_target_kind == "vc"
          && vcenter.placement.kind != "nested_vsphere"
          ? local.vcenter_target_paths[name]
          : null
        )
      }
      ansible = {
        host = vcenter.ip
        user = "root"
      }
      api = {
        host = vcenter.ip
        user = "administrator@${try(vcenter.sso_domain_name, "vsphere.local")}"
      }
    }
    if contains(keys(local.routers), try(vcenter.router, ""))
    && contains(keys(local.vcenter_defaults), name)
    && local.vcenter_source_refs[name] != null
    && contains(keys(local.install_sources), local.vcenter_source_refs[name])
    && contains(local.supported_vcenter_source_types, try(local.install_sources[local.vcenter_source_refs[name]].type, ""))
    && contains(local.supported_vcenter_placements, try(vcenter.placement.kind, ""))
    && local.vcenter_defaults[name].network_name != null
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
      datastore_cdroms = [
        for source_name in local.router_vcenter_datastore_iso_sources[name] : {
          source_name = source_name
          datastore   = local.install_sources[source_name].datastore
          path        = local.install_sources[source_name].path
          device_path = local.router_datastore_iso_source_devices[name][source_name].device_path
        }
      ]
      services = local.router_service_flags[name]
      runtime  = local.router_runtime_paths[name]
      ansible  = local.router_ansible[name]
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
      vmkernel_adapters    = try(local.esxi_group_host_vmkernel_adapters[host_key], [])
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
      name                   = module.routers[name].name
      wan_ip                 = module.routers[name].wan_ip
      management_network     = module.routers[name].management_network
      management_ip          = local.router_management_ips[name]
      placement              = router.placement
      networks               = router.networks
      services               = router.services
      runtime                = router.runtime
      evpn                   = module.routers[name].evpn
      install_source         = local.router_source_refs[name]
      install_source_devices = local.router_datastore_iso_source_devices[name]
      ansible                = merge(router.ansible, { host = module.routers[name].wan_ip })
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
          vmkernel_adapters   = try(host.vmkernel_adapters, [])
          mac_addresses       = module.esxi_hosts[host.key].mac_addresses
          primary_mac_address = module.esxi_hosts[host.key].primary_mac_address
          group               = name
          ansible = {
            host     = host.ip
            user     = "root"
            password = var.vm_admin_password
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

  vcenter_outputs = {
    for name, vcenter in local.vcenter_runtime :
    name => {
      name            = vcenter.name
      router          = vcenter.router
      hostname        = vcenter.hostname
      fqdn            = vcenter.fqdn
      ip              = vcenter.ip
      placement       = vcenter.placement
      network         = vcenter.network
      deployment_size = vcenter.deployment_size
      sso_domain_name = vcenter.sso_domain_name
      manages         = vcenter.manages
      depots          = vcenter.depots
      managed_hosts = flatten([
        for managed_group in vcenter.manages : try(local.esxi_group_outputs[managed_group].hosts, [])
      ])
      registration = {
        datacenter = coalesce(
          try(vcenter.target.storage.vsan.datacenter, null),
          "Datacenter"
        )
        cluster = coalesce(
          try(vcenter.target.storage.vsan.cluster, null),
          "Cluster"
        )
      }
      ntp_servers = vcenter.ntp_servers
      install     = vcenter.install
      target      = vcenter.target
      ansible     = vcenter.ansible
      api         = vcenter.api
    }
  }
}
