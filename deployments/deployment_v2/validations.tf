locals {
  routers_missing_source = [
    for name, source_ref in local.router_source_refs : name
    if source_ref == null
  ]

  routers_missing_sources = [
    for name, source_ref in local.router_source_refs : "${name}:${source_ref}"
    if source_ref != null && !contains(keys(local.install_sources), source_ref)
  ]

  routers_invalid_source_type = [
    for name, source_ref in local.router_source_refs : "${name}:${local.install_sources[source_ref].type}"
    if source_ref != null
    && contains(keys(local.install_sources), source_ref)
    && !contains(local.supported_router_source_types, local.install_sources[source_ref].type)
  ]

  routers_unsupported_placement = [
    for name, router in local.routers : "${name}:${try(router.placement.kind, "unset")}"
    if !contains(local.supported_router_placements, try(router.placement.kind, ""))
  ]

  routers_placement_overrides = [
    for name, router in local.routers : name
    if(
      try(router.placement.datacenter, local.provider.datacenter) != local.provider.datacenter
      || try(router.placement.resource_pool, local.provider.resource_pool) != local.provider.resource_pool
      || try(router.placement.host, local.provider.compute_host) != local.provider.compute_host
      || try(router.placement.datastore, local.provider.datastore) != local.provider.datastore
    )
  ]

  esxi_groups_missing_router = [
    for name, group in local.esxi_groups : name
    if !contains(keys(local.routers), try(group.router, ""))
  ]

  esxi_groups_missing_install_source = [
    for name, group in local.esxi_groups : name
    if try(group.install.source.install_source, null) == null
  ]

  esxi_groups_unknown_install_source = [
    for name, group in local.esxi_groups : "${name}:${try(group.install.source.install_source, "unset")}"
    if try(group.install.source.install_source, null) != null
    && !contains(keys(local.install_sources), try(group.install.source.install_source, ""))
  ]

  esxi_groups_invalid_install_source_type = [
    for name, group in local.esxi_groups : "${name}:${local.install_sources[group.install.source.install_source].type}"
    if try(group.install.source.install_source, null) != null
    && contains(keys(local.install_sources), try(group.install.source.install_source, ""))
    && !contains(local.supported_esxi_install_source_types, local.install_sources[group.install.source.install_source].type)
  ]

  esxi_groups_install_source_method_mismatch = [
    for name, group in local.esxi_groups : "${name}:${local.install_sources[group.install.source.install_source].type}:${try(group.install.method, "unset")}"
    if try(group.install.source.install_source, null) != null
    && contains(keys(local.install_sources), try(group.install.source.install_source, ""))
    && (
      (
        try(group.install.method, "") == "ansible_router_pxe"
        && !contains(["http_iso", "rclone_iso"], local.install_sources[group.install.source.install_source].type)
      )
      || (
        try(group.install.method, "") == "ansible_vsphere_iso_boot"
        && local.install_sources[group.install.source.install_source].type != "datastore_iso"
      )
    )
  ]

  esxi_groups_unsupported_placement = [
    for name, group in local.esxi_groups : "${name}:${try(group.placement.kind, "unset")}"
    if !contains(local.supported_esxi_group_placements, try(group.placement.kind, ""))
  ]

  esxi_groups_unsupported_install_method = [
    for name, group in local.esxi_groups : "${name}:${try(group.install.method, "unset")}"
    if !contains(local.supported_esxi_install_methods, try(group.install.method, ""))
  ]

  esxi_groups_unsupported_kickstart_template = [
    for name, group in local.esxi_groups : "${name}:${try(group.install.kickstart.template, "unset")}"
    if try(group.install.kickstart.template, null) != null
    && !contains(local.supported_esxi_kickstart_templates, try(group.install.kickstart.template, ""))
  ]

  esxi_groups_placement_overrides = [
    for name, group in local.esxi_groups : name
    if contains(local.supported_esxi_group_placements, try(group.placement.kind, ""))
    && (
      try(group.placement.datacenter, local.provider.datacenter) != local.provider.datacenter
      || try(group.placement.resource_pool, local.provider.resource_pool) != local.provider.resource_pool
      || try(group.placement.host, local.provider.compute_host) != local.provider.compute_host
      || try(group.placement.datastore, local.provider.datastore) != local.provider.datastore
    )
  ]

  esxi_groups_missing_ntp_servers = [
    for name, group in local.esxi_groups : name
    if try(length(group.ntp_servers), 0) == 0
  ]

  esxi_groups_invalid_ntp_servers = [
    for name, group in local.esxi_groups : name
    if try(length(group.ntp_servers), 0) > 0
    && length([
      for server in try(group.ntp_servers, []) : server
      if try(trimspace(server), "") != ""
    ]) != length(try(group.ntp_servers, []))
  ]

  esxi_group_vmkernel_adapter_refs = flatten([
    for group_name, group in local.esxi_groups : [
      for idx, adapter in coalesce(try(group.vmkernel_adapters, null), []) : {
        group                     = group_name
        index                     = idx
        id                        = "${group_name}[${idx}]"
        router                    = try(group.router, "")
        group_count               = try(tonumber(group.count), null)
        nic_count                 = try(tonumber(group.shape.nic_count), null)
        router_vlan_start         = try(tonumber(local.routers[group.router].networks.lan.vlan_starts_with), null)
        router_vlan_count         = try(tonumber(local.routers[group.router].networks.lan.vlan_network_count), null)
        router_mtu                = try(tonumber(local.routers[group.router].networks.lan.mtu), null)
        name                      = trimspace(try(tostring(adapter.name), ""))
        purpose                   = trimspace(try(tostring(adapter.purpose), ""))
        vswitch                   = trimspace(try(tostring(adapter.vswitch), ""))
        portgroup                 = trimspace(try(tostring(adapter.portgroup), ""))
        uplink                    = trimspace(try(tostring(adapter.uplink), ""))
        vlan                      = try(tonumber(adapter.vlan), null)
        vlan_raw                  = try(tostring(adapter.vlan), "")
        mtu                       = try(tonumber(adapter.mtu), try(tonumber(local.routers[group.router].networks.lan.mtu), null))
        mtu_raw                   = try(tostring(adapter.mtu), "")
        subnet                    = trimspace(try(tostring(adapter.subnet), ""))
        ip                        = trimspace(try(tostring(adapter.ip), ""))
        ip_offset_from_management = coalesce(try(adapter.ip_offset_from_management, null), true)
      }
    ]
  ])

  esxi_groups_vmkernel_adapters_missing_fields = [
    for ref in local.esxi_group_vmkernel_adapter_refs : ref.id
    if ref.name == ""
    || ref.purpose == ""
    || ref.vswitch == ""
    || ref.portgroup == ""
    || ref.uplink == ""
    || ref.vlan_raw == ""
    || ref.subnet == ""
  ]

  esxi_groups_vmkernel_adapters_invalid_names = [
    for ref in local.esxi_group_vmkernel_adapter_refs : "${ref.id}:${ref.name}"
    if !can(regex("^vmk[0-9]+$", ref.name))
  ]

  esxi_groups_vmkernel_adapters_duplicate_names = flatten([
    for group_name, group in local.esxi_groups : [
      for name in distinct(compact([
        for adapter in coalesce(try(group.vmkernel_adapters, null), []) : trimspace(try(tostring(adapter.name), ""))
      ])) : "${group_name}:${name}"
      if length([
        for adapter in coalesce(try(group.vmkernel_adapters, null), []) : adapter
        if trimspace(try(tostring(adapter.name), "")) == name
      ]) > 1
    ]
  ])

  esxi_groups_vmkernel_adapters_duplicate_purposes = flatten([
    for group_name, group in local.esxi_groups : [
      for purpose in distinct(compact([
        for adapter in coalesce(try(group.vmkernel_adapters, null), []) : trimspace(try(tostring(adapter.purpose), ""))
      ])) : "${group_name}:${purpose}"
      if length([
        for adapter in coalesce(try(group.vmkernel_adapters, null), []) : adapter
        if trimspace(try(tostring(adapter.purpose), "")) == purpose
      ]) > 1
    ]
  ])

  esxi_groups_vmkernel_adapters_invalid_subnets = [
    for ref in local.esxi_group_vmkernel_adapter_refs : "${ref.id}:${ref.subnet}"
    if !can(cidrhost(ref.subnet, 0)) || !can(cidrnetmask(ref.subnet))
  ]

  esxi_groups_vmkernel_adapters_invalid_ips = [
    for ref in local.esxi_group_vmkernel_adapter_refs : "${ref.id}:${ref.ip}"
    if ref.ip != "" && !can(cidrhost("${ref.ip}/32", 0))
  ]

  esxi_groups_vmkernel_adapters_invalid_vlans = [
    for ref in local.esxi_group_vmkernel_adapter_refs : "${ref.id}:${ref.vlan_raw}"
    if try(ref.vlan < 0 || ref.vlan > 4094, true)
  ]

  esxi_groups_vmkernel_adapters_vlan_outside_router_range = [
    for ref in local.esxi_group_vmkernel_adapter_refs : "${ref.id}:${ref.vlan}"
    if try(
      ref.vlan < ref.router_vlan_start
      || ref.vlan >= ref.router_vlan_start + ref.router_vlan_count,
      false
    )
  ]

  esxi_groups_vmkernel_adapters_invalid_uplinks = [
    for ref in local.esxi_group_vmkernel_adapter_refs : "${ref.id}:${ref.uplink}"
    if !can(regex("^vmnic[0-9]+$", ref.uplink))
    || try(tonumber(replace(ref.uplink, "vmnic", "")) >= ref.nic_count, true)
  ]

  esxi_groups_vmkernel_adapters_invalid_mtu = [
    for ref in local.esxi_group_vmkernel_adapter_refs : "${ref.id}:${ref.mtu}"
    if try(
      ref.mtu < 576
      || ref.mtu > 9000
      || ref.mtu > ref.router_mtu,
      true
    )
  ]

  esxi_groups_vmkernel_adapters_static_ip_on_multi_host_group = [
    for ref in local.esxi_group_vmkernel_adapter_refs : "${ref.id}:${ref.ip}"
    if ref.ip != "" && try(ref.group_count > 1, false)
  ]

  esxi_groups_vmkernel_adapters_missing_ip_source = [
    for ref in local.esxi_group_vmkernel_adapter_refs : ref.id
    if ref.ip == "" && !ref.ip_offset_from_management
  ]

  storages_missing_router = [
    for name, storage in local.storages : name
    if !contains(keys(local.routers), try(storage.router, ""))
  ]

  storages_missing_source = [
    for name, source_ref in local.storage_source_refs : name
    if source_ref == null
  ]

  storages_missing_sources = [
    for name, source_ref in local.storage_source_refs : "${name}:${source_ref}"
    if source_ref != null && !contains(keys(local.install_sources), source_ref)
  ]

  storages_invalid_source_type = [
    for name, source_ref in local.storage_source_refs : "${name}:${local.install_sources[source_ref].type}"
    if source_ref != null
    && contains(keys(local.install_sources), source_ref)
    && !contains(local.supported_storage_source_types, local.install_sources[source_ref].type)
  ]

  storages_unsupported_placement = [
    for name, storage in local.storages : "${name}:${try(storage.placement.kind, "unset")}"
    if !contains(local.supported_storage_placements, try(storage.placement.kind, ""))
  ]

  storages_placement_overrides = [
    for name, storage in local.storages : name
    if contains(local.supported_storage_placements, try(storage.placement.kind, ""))
    && (
      try(storage.placement.datacenter, local.provider.datacenter) != local.provider.datacenter
      || try(storage.placement.resource_pool, local.provider.resource_pool) != local.provider.resource_pool
      || try(storage.placement.host, local.provider.compute_host) != local.provider.compute_host
      || try(storage.placement.datastore, local.provider.datastore) != local.provider.datastore
    )
  ]

  vcenters_missing_router = [
    for name, vcenter in local.vcenters : name
    if !contains(keys(local.routers), try(vcenter.router, ""))
  ]

  vcenters_missing_source = [
    for name, source_ref in local.vcenter_source_refs : name
    if source_ref == null
  ]

  vcenters_missing_sources = [
    for name, source_ref in local.vcenter_source_refs : "${name}:${source_ref}"
    if source_ref != null && !contains(keys(local.install_sources), source_ref)
  ]

  vcenters_invalid_source_type = [
    for name, source_ref in local.vcenter_source_refs : "${name}:${local.install_sources[source_ref].type}"
    if source_ref != null
    && contains(keys(local.install_sources), source_ref)
    && !contains(local.supported_vcenter_source_types, local.install_sources[source_ref].type)
  ]

  vcenters_unsupported_placement = [
    for name, vcenter in local.vcenters : "${name}:${try(vcenter.placement.kind, "unset")}"
    if !contains(local.supported_vcenter_placements, try(vcenter.placement.kind, ""))
  ]

  vcenters_missing_nested_esxi_group = [
    for name, vcenter in local.vcenters : name
    if try(vcenter.placement.kind, "") == "nested_vsphere"
    && coalesce(try(vcenter.placement.esxi_group, null), "") == ""
  ]

  vcenters_missing_nested_host = [
    for name, vcenter in local.vcenters : name
    if try(vcenter.placement.kind, "") == "nested_vsphere"
    && coalesce(try(vcenter.placement.host, null), "") == ""
  ]

  vcenters_missing_nested_datastore = [
    for name, vcenter in local.vcenters : name
    if try(vcenter.placement.kind, "") == "nested_vsphere"
    && coalesce(try(vcenter.placement.datastore, null), "") == ""
  ]

  vcenters_missing_nested_network = [
    for name, vcenter in local.vcenters : name
    if try(vcenter.placement.kind, "") == "nested_vsphere"
    && coalesce(try(vcenter.placement.network, null), "") == ""
  ]

  vcenters_unknown_nested_esxi_group = [
    for name, vcenter in local.vcenters : "${name}:${try(vcenter.placement.esxi_group, "unset")}"
    if try(vcenter.placement.kind, "") == "nested_vsphere"
    && coalesce(try(vcenter.placement.esxi_group, null), "") != ""
    && !contains(keys(local.esxi_groups), try(vcenter.placement.esxi_group, ""))
  ]

  vcenters_nested_esxi_group_router_mismatch = [
    for name, vcenter in local.vcenters : "${name}:${try(vcenter.placement.esxi_group, "unset")}"
    if try(vcenter.placement.kind, "") == "nested_vsphere"
    && contains(keys(local.esxi_groups), try(vcenter.placement.esxi_group, ""))
    && try(local.esxi_groups[vcenter.placement.esxi_group].router, "") != try(vcenter.router, "")
  ]

  vcenters_unknown_nested_host = [
    for name, vcenter in local.vcenters : "${name}:${try(vcenter.placement.esxi_group, "unset")}/${try(vcenter.placement.host, "unset")}"
    if try(vcenter.placement.kind, "") == "nested_vsphere"
    && contains(keys(local.esxi_groups), try(vcenter.placement.esxi_group, ""))
    && coalesce(try(vcenter.placement.host, null), "") != ""
    && length(try(local.vcenter_nested_target_host_matches[name], [])) != 1
  ]

  vcenters_invalid_nested_storage_mode = [
    for name, vcenter in local.vcenters : "${name}:${try(vcenter.placement.storage.mode, "existing_datastore")}"
    if try(vcenter.placement.kind, "") == "nested_vsphere"
    && !contains(local.supported_vcenter_nested_storage_modes, try(vcenter.placement.storage.mode, "existing_datastore"))
  ]

  vcenters_missing_iscsi_storage = [
    for name, vcenter in local.vcenters : name
    if try(vcenter.placement.kind, "") == "nested_vsphere"
    && try(vcenter.placement.storage.mode, "existing_datastore") == "iscsi_datastore"
    && coalesce(try(vcenter.placement.storage.storage, null), "") == ""
  ]

  vcenters_missing_iscsi_lun = [
    for name, vcenter in local.vcenters : name
    if try(vcenter.placement.kind, "") == "nested_vsphere"
    && try(vcenter.placement.storage.mode, "existing_datastore") == "iscsi_datastore"
    && coalesce(try(vcenter.placement.storage.lun, null), "") == ""
  ]

  vcenters_iscsi_target_iqn_set = [
    for name, vcenter in local.vcenters : name
    if try(vcenter.placement.kind, "") == "nested_vsphere"
    && try(vcenter.placement.storage.mode, "existing_datastore") == "iscsi_datastore"
    && try(vcenter.placement.storage.target_iqn, null) != null
  ]

  vcenters_unknown_iscsi_storage = [
    for name, vcenter in local.vcenters : "${name}:${try(vcenter.placement.storage.storage, "unset")}"
    if try(vcenter.placement.kind, "") == "nested_vsphere"
    && try(vcenter.placement.storage.mode, "existing_datastore") == "iscsi_datastore"
    && coalesce(try(vcenter.placement.storage.storage, null), "") != ""
    && !contains(keys(local.storages), try(vcenter.placement.storage.storage, ""))
  ]

  vcenters_iscsi_storage_router_mismatch = [
    for name, vcenter in local.vcenters : "${name}:${try(vcenter.placement.storage.storage, "unset")}"
    if try(vcenter.placement.kind, "") == "nested_vsphere"
    && try(vcenter.placement.storage.mode, "existing_datastore") == "iscsi_datastore"
    && contains(keys(local.storages), try(vcenter.placement.storage.storage, ""))
    && try(local.storages[vcenter.placement.storage.storage].router, "") != try(vcenter.router, "")
  ]

  vcenters_unknown_iscsi_lun = [
    for name, vcenter in local.vcenters : "${name}:${try(vcenter.placement.storage.storage, "unset")}/${try(vcenter.placement.storage.lun, "unset")}"
    if try(vcenter.placement.kind, "") == "nested_vsphere"
    && try(vcenter.placement.storage.mode, "existing_datastore") == "iscsi_datastore"
    && contains(keys(local.storages), try(vcenter.placement.storage.storage, ""))
    && coalesce(try(vcenter.placement.storage.lun, null), "") != ""
    && !contains(keys(local.storage_luns), "${try(vcenter.placement.storage.storage, "")}/${try(vcenter.placement.storage.lun, "")}")
  ]

  vcenters_missing_iscsi_vmkernel_purposes = [
    for name, vcenter in local.vcenters : name
    if try(vcenter.placement.kind, "") == "nested_vsphere"
    && try(vcenter.placement.storage.mode, "existing_datastore") == "iscsi_datastore"
    && try(length(vcenter.placement.storage.vmkernel_purposes), 0) == 0
  ]

  vcenter_iscsi_vmkernel_purpose_refs = flatten([
    for name, vcenter in local.vcenters : [
      for purpose in try(vcenter.placement.storage.vmkernel_purposes, []) : {
        vcenter    = name
        esxi_group = try(vcenter.placement.esxi_group, "")
        purpose    = trimspace(try(tostring(purpose), ""))
      }
    ]
    if try(vcenter.placement.kind, "") == "nested_vsphere"
    && try(vcenter.placement.storage.mode, "existing_datastore") == "iscsi_datastore"
  ])

  vcenters_unknown_iscsi_vmkernel_purposes = [
    for ref in local.vcenter_iscsi_vmkernel_purpose_refs : "${ref.vcenter}:${ref.esxi_group}:${ref.purpose}"
    if !contains([
      for adapter in coalesce(try(local.esxi_groups[ref.esxi_group].vmkernel_adapters, null), []) :
      trimspace(try(tostring(adapter.purpose), ""))
    ], ref.purpose)
  ]

  vcenters_iscsi_port_binding_multiple_subnets = [
    for name, vcenter in local.vcenters : name
    if try(vcenter.placement.kind, "") == "nested_vsphere"
    && try(vcenter.placement.storage.mode, "existing_datastore") == "iscsi_datastore"
    && coalesce(try(vcenter.placement.storage.port_binding, null), false)
    && length(distinct(compact([
      for adapter in coalesce(try(local.esxi_groups[vcenter.placement.esxi_group].vmkernel_adapters, null), []) :
      trimspace(try(tostring(adapter.subnet), ""))
      if contains(
        try(vcenter.placement.storage.vmkernel_purposes, []),
        trimspace(try(tostring(adapter.purpose), ""))
      )
    ]))) > 1
  ]

  vcenters_missing_vsan_datastore_name = [
    for name, vcenter in local.vcenters : name
    if try(vcenter.placement.kind, "") == "nested_vsphere"
    && try(vcenter.placement.storage.mode, "existing_datastore") == "vsan_bootstrap"
    && coalesce(try(vcenter.placement.storage.vsan.datastore_name, try(vcenter.placement.datastore, null)), "") == ""
  ]

  vcenters_missing_vsan_datacenter = [
    for name, vcenter in local.vcenters : name
    if try(vcenter.placement.kind, "") == "nested_vsphere"
    && try(vcenter.placement.storage.mode, "existing_datastore") == "vsan_bootstrap"
    && coalesce(try(vcenter.placement.storage.vsan.datacenter, null), "") == ""
  ]

  vcenters_missing_vsan_cluster = [
    for name, vcenter in local.vcenters : name
    if try(vcenter.placement.kind, "") == "nested_vsphere"
    && try(vcenter.placement.storage.mode, "existing_datastore") == "vsan_bootstrap"
    && coalesce(try(vcenter.placement.storage.vsan.cluster, null), "") == ""
  ]

  vcenters_missing_vsan_cache_disks = [
    for name, vcenter in local.vcenters : name
    if try(vcenter.placement.kind, "") == "nested_vsphere"
    && try(vcenter.placement.storage.mode, "existing_datastore") == "vsan_bootstrap"
    && try(length(vcenter.placement.storage.vsan.cache_disks), 0) == 0
  ]

  vcenters_missing_vsan_capacity_disks = [
    for name, vcenter in local.vcenters : name
    if try(vcenter.placement.kind, "") == "nested_vsphere"
    && try(vcenter.placement.storage.mode, "existing_datastore") == "vsan_bootstrap"
    && try(length(vcenter.placement.storage.vsan.capacity_disks), 0) == 0
  ]

  vcenters_invalid_vsan_compression_mode = [
    for name, vcenter in local.vcenters : name
    if try(vcenter.placement.kind, "") == "nested_vsphere"
    && try(vcenter.placement.storage.mode, "existing_datastore") == "vsan_bootstrap"
    && try(vcenter.placement.storage.vsan.compression_only, false)
    && try(vcenter.placement.storage.vsan.deduplication_and_compression, false)
  ]

  vcenters_vsan_bootstrap_unknown_vcsa_version = [
    for name, vcenter in local.vcenters : "${name}:${local.vcenter_source_refs[name]}"
    if try(vcenter.placement.kind, "") == "nested_vsphere"
    && try(vcenter.placement.storage.mode, "existing_datastore") == "vsan_bootstrap"
    && local.vcenter_source_refs[name] != null
    && contains(keys(local.install_sources), local.vcenter_source_refs[name])
    && !local.install_source_vcenter_versions[local.vcenter_source_refs[name]].detected
  ]

  vcenters_vsan_bootstrap_unsupported_vcsa_version = [
    for name, vcenter in local.vcenters : "${name}:${local.vcenter_source_refs[name]}:${local.install_source_vcenter_versions[local.vcenter_source_refs[name]].label}"
    if try(vcenter.placement.kind, "") == "nested_vsphere"
    && try(vcenter.placement.storage.mode, "existing_datastore") == "vsan_bootstrap"
    && local.vcenter_source_refs[name] != null
    && contains(keys(local.install_sources), local.vcenter_source_refs[name])
    && local.install_source_vcenter_versions[local.vcenter_source_refs[name]].detected
    && !local.install_source_supports_vsan_bootstrap[local.vcenter_source_refs[name]]
  ]

  vcenters_empty_manages = [
    for name, vcenter in local.vcenters : name
    if try(length(vcenter.manages), 0) == 0
  ]

  vcenters_unknown_managed_esxi_groups = flatten([
    for name, vcenter in local.vcenters : [
      for managed_group in try(vcenter.manages, []) : "${name}:${managed_group}"
      if !contains(keys(local.esxi_groups), managed_group)
    ]
  ])

  vcenter_managed_esxi_group_refs = flatten([
    for name, vcenter in local.vcenters : [
      for managed_group in try(vcenter.manages, []) : {
        vcenter = name
        group   = managed_group
      }
      if contains(keys(local.esxi_groups), managed_group)
    ]
  ])

  vcenters_duplicate_managed_esxi_groups = sort(distinct([
    for ref in local.vcenter_managed_esxi_group_refs : ref.group
    if length([
      for candidate in local.vcenter_managed_esxi_group_refs : candidate
      if candidate.group == ref.group
    ]) > 1
  ]))

  vcenters_managed_esxi_group_router_mismatch = flatten([
    for name, vcenter in local.vcenters : [
      for managed_group in try(vcenter.manages, []) : "${name}:${managed_group}"
      if contains(keys(local.esxi_groups), managed_group)
      && try(local.esxi_groups[managed_group].router, "") != try(vcenter.router, "")
    ]
  ])

  vcenters_missing_network = [
    for name, _ in local.vcenters : name
    if contains(keys(local.routers), try(local.vcenters[name].router, ""))
    && try(local.vcenter_defaults[name].network_name, null) == null
  ]

  vcenters_missing_provider_credentials = compact([
    length([
      for _, vcenter in local.vcenters : vcenter
      if try(vcenter.placement.kind, "") == "provider_vsphere"
    ]) > 0 && try(local.provider.server, null) == null ? "provider_config.server" : null,
    length([
      for _, vcenter in local.vcenters : vcenter
      if try(vcenter.placement.kind, "") == "provider_vsphere"
    ]) > 0 && try(local.provider.user, null) == null ? "provider_config.user" : null,
    length([
      for _, vcenter in local.vcenters : vcenter
      if try(vcenter.placement.kind, "") == "provider_vsphere"
    ]) > 0 && try(local.provider.password, null) == null ? "provider_config.password" : null,
  ])

}

resource "terraform_data" "validate_router_inputs" {
  input = {
    routers = keys(local.routers)
  }

  lifecycle {
    precondition {
      condition     = length(local.routers_missing_source) == 0
      error_message = "Each router must define source.install_source or template. Missing: ${join(", ", local.routers_missing_source)}"
    }

    precondition {
      condition     = length(local.routers_missing_sources) == 0
      error_message = "Router install_source reference was not found in install_sources: ${join(", ", local.routers_missing_sources)}"
    }

    precondition {
      condition     = length(local.routers_invalid_source_type) == 0
      error_message = "Router install_source type must be one of http_ovf or local_ovf. Invalid: ${join(", ", local.routers_invalid_source_type)}"
    }

    precondition {
      condition     = length(local.routers_unsupported_placement) == 0
      error_message = "Router placement.kind currently supports only provider_vsphere. Invalid: ${join(", ", local.routers_unsupported_placement)}"
    }

    precondition {
      condition     = length(local.routers_placement_overrides) == 0
      error_message = "Router placement overrides are not implemented yet. Use provider_config values for datacenter/resource_pool/host/datastore. Invalid: ${join(", ", local.routers_placement_overrides)}"
    }

  }
}

resource "terraform_data" "validate_esxi_group_inputs" {
  input = {
    esxi_groups = keys(local.esxi_groups)
  }

  lifecycle {
    precondition {
      condition     = length(local.esxi_groups_missing_router) == 0
      error_message = "Each esxi_group must reference an existing router. Invalid: ${join(", ", local.esxi_groups_missing_router)}"
    }

    precondition {
      condition     = length(local.esxi_groups_missing_install_source) == 0
      error_message = "Each esxi_group must define install.source.install_source. Missing: ${join(", ", local.esxi_groups_missing_install_source)}"
    }

    precondition {
      condition     = length(local.esxi_groups_unknown_install_source) == 0
      error_message = "ESXi install_source reference was not found in install_sources: ${join(", ", local.esxi_groups_unknown_install_source)}"
    }

    precondition {
      condition     = length(local.esxi_groups_invalid_install_source_type) == 0
      error_message = "ESXi install_source type must currently be http_iso, rclone_iso, or datastore_iso. Invalid: ${join(", ", local.esxi_groups_invalid_install_source_type)}"
    }

    precondition {
      condition     = length(local.esxi_groups_unsupported_placement) == 0
      error_message = "ESXi placement.kind currently supports only provider_vsphere. Invalid: ${join(", ", local.esxi_groups_unsupported_placement)}"
    }

    precondition {
      condition     = length(local.esxi_groups_unsupported_install_method) == 0
      error_message = "ESXi install.method currently supports ansible_router_pxe or ansible_vsphere_iso_boot. Invalid: ${join(", ", local.esxi_groups_unsupported_install_method)}"
    }

    precondition {
      condition     = length(local.esxi_groups_install_source_method_mismatch) == 0
      error_message = "ESXi install_source type must match install.method. Use http_iso/rclone_iso with ansible_router_pxe, and datastore_iso with ansible_vsphere_iso_boot. Invalid: ${join(", ", local.esxi_groups_install_source_method_mismatch)}"
    }

    precondition {
      condition     = length(local.esxi_groups_unsupported_kickstart_template) == 0
      error_message = "ESXi install.kickstart.template currently supports only esxi-8.0. Invalid: ${join(", ", local.esxi_groups_unsupported_kickstart_template)}"
    }

    precondition {
      condition     = length(local.esxi_groups_placement_overrides) == 0
      error_message = "ESXi placement overrides are not implemented yet. Use provider_config values for datacenter/resource_pool/host/datastore. Invalid: ${join(", ", local.esxi_groups_placement_overrides)}"
    }

    precondition {
      condition     = length(local.esxi_groups_missing_ntp_servers) == 0
      error_message = "Each esxi_group must define at least one ntp_servers entry. Missing: ${join(", ", local.esxi_groups_missing_ntp_servers)}"
    }

    precondition {
      condition     = length(local.esxi_groups_invalid_ntp_servers) == 0
      error_message = "Each esxi_group ntp_servers entry must be a non-empty string. Invalid: ${join(", ", local.esxi_groups_invalid_ntp_servers)}"
    }

    precondition {
      condition     = length(local.esxi_groups_vmkernel_adapters_missing_fields) == 0
      error_message = "Each esxi_group vmkernel_adapters entry must define name, purpose, vswitch, portgroup, uplink, vlan, and subnet. Invalid: ${join(", ", local.esxi_groups_vmkernel_adapters_missing_fields)}"
    }

    precondition {
      condition     = length(local.esxi_groups_vmkernel_adapters_invalid_names) == 0
      error_message = "Each esxi_group vmkernel_adapters name must match vmk<index>. Invalid: ${join(", ", local.esxi_groups_vmkernel_adapters_invalid_names)}"
    }

    precondition {
      condition     = length(local.esxi_groups_vmkernel_adapters_duplicate_names) == 0
      error_message = "Each esxi_group vmkernel_adapters name must be unique within the group. Duplicates: ${join(", ", local.esxi_groups_vmkernel_adapters_duplicate_names)}"
    }

    precondition {
      condition     = length(local.esxi_groups_vmkernel_adapters_duplicate_purposes) == 0
      error_message = "Each esxi_group vmkernel_adapters purpose must be unique within the group. Duplicates: ${join(", ", local.esxi_groups_vmkernel_adapters_duplicate_purposes)}"
    }

    precondition {
      condition     = length(local.esxi_groups_vmkernel_adapters_invalid_subnets) == 0
      error_message = "Each esxi_group vmkernel_adapters subnet must be an IPv4 CIDR. Invalid: ${join(", ", local.esxi_groups_vmkernel_adapters_invalid_subnets)}"
    }

    precondition {
      condition     = length(local.esxi_groups_vmkernel_adapters_invalid_ips) == 0
      error_message = "Each esxi_group vmkernel_adapters ip must be an IPv4 address when set. Invalid: ${join(", ", local.esxi_groups_vmkernel_adapters_invalid_ips)}"
    }

    precondition {
      condition     = length(local.esxi_groups_vmkernel_adapters_invalid_vlans) == 0
      error_message = "Each esxi_group vmkernel_adapters vlan must be an integer from 0 through 4094. Invalid: ${join(", ", local.esxi_groups_vmkernel_adapters_invalid_vlans)}"
    }

    precondition {
      condition     = length(local.esxi_groups_vmkernel_adapters_vlan_outside_router_range) == 0
      error_message = "Each esxi_group vmkernel_adapters vlan must fall within the Router LAN vlan_starts_with/vlan_network_count range. Invalid: ${join(", ", local.esxi_groups_vmkernel_adapters_vlan_outside_router_range)}"
    }

    precondition {
      condition     = length(local.esxi_groups_vmkernel_adapters_invalid_uplinks) == 0
      error_message = "Each esxi_group vmkernel_adapters uplink must match vmnic<index> and fit within shape.nic_count. Invalid: ${join(", ", local.esxi_groups_vmkernel_adapters_invalid_uplinks)}"
    }

    precondition {
      condition     = length(local.esxi_groups_vmkernel_adapters_invalid_mtu) == 0
      error_message = "Each esxi_group vmkernel_adapters mtu must be between 576 and 9000 and no larger than the Router LAN MTU. Invalid: ${join(", ", local.esxi_groups_vmkernel_adapters_invalid_mtu)}"
    }

    precondition {
      condition     = length(local.esxi_groups_vmkernel_adapters_static_ip_on_multi_host_group) == 0
      error_message = "Static vmkernel_adapters ip is allowed only on single-host ESXi groups; omit ip to derive one per host. Invalid: ${join(", ", local.esxi_groups_vmkernel_adapters_static_ip_on_multi_host_group)}"
    }

    precondition {
      condition     = length(local.esxi_groups_vmkernel_adapters_missing_ip_source) == 0
      error_message = "Each esxi_group vmkernel_adapters entry must either set ip or leave ip_offset_from_management enabled. Invalid: ${join(", ", local.esxi_groups_vmkernel_adapters_missing_ip_source)}"
    }
  }
}

resource "terraform_data" "validate_storage_inputs" {
  input = {
    storages = keys(local.storages)
  }

  lifecycle {
    precondition {
      condition     = length(local.storages_missing_router) == 0
      error_message = "Each storage must reference an existing router. Invalid: ${join(", ", local.storages_missing_router)}"
    }

    precondition {
      condition     = length(local.storages_missing_source) == 0
      error_message = "Each storage must define source.install_source or template. Missing: ${join(", ", local.storages_missing_source)}"
    }

    precondition {
      condition     = length(local.storages_missing_sources) == 0
      error_message = "Storage install_source reference was not found in install_sources: ${join(", ", local.storages_missing_sources)}"
    }

    precondition {
      condition     = length(local.storages_invalid_source_type) == 0
      error_message = "Storage install_source type must be one of http_ovf or local_ovf. Invalid: ${join(", ", local.storages_invalid_source_type)}"
    }

    precondition {
      condition     = length(local.storages_unsupported_placement) == 0
      error_message = "Storage placement.kind currently supports only provider_vsphere. Invalid: ${join(", ", local.storages_unsupported_placement)}"
    }

    precondition {
      condition     = length(local.storages_placement_overrides) == 0
      error_message = "Storage placement overrides are not implemented yet. Use provider_config values for datacenter/resource_pool/host/datastore. Invalid: ${join(", ", local.storages_placement_overrides)}"
    }
  }
}

resource "terraform_data" "validate_vcenter_inputs" {
  input = {
    vcenters = keys(local.vcenters)
  }

  lifecycle {
    precondition {
      condition     = length(local.vcenters_missing_router) == 0
      error_message = "Each vcenter must reference an existing router. Invalid: ${join(", ", local.vcenters_missing_router)}"
    }

    precondition {
      condition     = length(local.vcenters_missing_source) == 0
      error_message = "Each vcenter must define source.install_source. Missing: ${join(", ", local.vcenters_missing_source)}"
    }

    precondition {
      condition     = length(local.vcenters_missing_sources) == 0
      error_message = "vCenter install_source reference was not found in install_sources: ${join(", ", local.vcenters_missing_sources)}"
    }

    precondition {
      condition     = length(local.vcenters_invalid_source_type) == 0
      error_message = "vCenter install_source type must currently be http_iso, rclone_iso, or datastore_iso. Invalid: ${join(", ", local.vcenters_invalid_source_type)}"
    }

    precondition {
      condition     = length(local.vcenters_unsupported_placement) == 0
      error_message = "vCenter placement.kind currently supports only provider_vsphere or nested_vsphere. Invalid: ${join(", ", local.vcenters_unsupported_placement)}"
    }

    precondition {
      condition     = length(local.vcenters_missing_nested_esxi_group) == 0
      error_message = "nested_vsphere vCenter placement must define placement.esxi_group. Missing: ${join(", ", local.vcenters_missing_nested_esxi_group)}"
    }

    precondition {
      condition     = length(local.vcenters_missing_nested_host) == 0
      error_message = "nested_vsphere vCenter placement must define placement.host as a host in placement.esxi_group. Missing: ${join(", ", local.vcenters_missing_nested_host)}"
    }

    precondition {
      condition     = length(local.vcenters_missing_nested_datastore) == 0
      error_message = "nested_vsphere vCenter placement must define placement.datastore for the ESXi target. Missing: ${join(", ", local.vcenters_missing_nested_datastore)}"
    }

    precondition {
      condition     = length(local.vcenters_missing_nested_network) == 0
      error_message = "nested_vsphere vCenter placement must define placement.network for the ESXi target. Missing: ${join(", ", local.vcenters_missing_nested_network)}"
    }

    precondition {
      condition     = length(local.vcenters_unknown_nested_esxi_group) == 0
      error_message = "nested_vsphere vCenter placement.esxi_group must reference an existing esxi_group. Invalid: ${join(", ", local.vcenters_unknown_nested_esxi_group)}"
    }

    precondition {
      condition     = length(local.vcenters_nested_esxi_group_router_mismatch) == 0
      error_message = "nested_vsphere vCenter placement.esxi_group must be attached to the same router. Invalid: ${join(", ", local.vcenters_nested_esxi_group_router_mismatch)}"
    }

    precondition {
      condition     = length(local.vcenters_unknown_nested_host) == 0
      error_message = "nested_vsphere vCenter placement.host must match exactly one host hostname, FQDN, or IP in placement.esxi_group. Invalid: ${join(", ", local.vcenters_unknown_nested_host)}"
    }

    precondition {
      condition     = length(local.vcenters_invalid_nested_storage_mode) == 0
      error_message = "nested_vsphere vCenter placement.storage.mode must be existing_datastore, iscsi_datastore, or vsan_bootstrap. Invalid: ${join(", ", local.vcenters_invalid_nested_storage_mode)}"
    }

    precondition {
      condition     = length(local.vcenters_missing_iscsi_storage) == 0
      error_message = "nested_vsphere vCenter iscsi_datastore storage mode must define placement.storage.storage. Missing: ${join(", ", local.vcenters_missing_iscsi_storage)}"
    }

    precondition {
      condition     = length(local.vcenters_missing_iscsi_lun) == 0
      error_message = "nested_vsphere vCenter iscsi_datastore storage mode must define placement.storage.lun. Missing: ${join(", ", local.vcenters_missing_iscsi_lun)}"
    }

    precondition {
      condition     = length(local.vcenters_iscsi_target_iqn_set) == 0
      error_message = "nested_vsphere vCenter iscsi_datastore must not define placement.storage.target_iqn; deployment_v2 derives the target path dynamically from software iSCSI discovery and the storage LUN ID. Invalid: ${join(", ", local.vcenters_iscsi_target_iqn_set)}"
    }

    precondition {
      condition     = length(local.vcenters_unknown_iscsi_storage) == 0
      error_message = "nested_vsphere vCenter placement.storage.storage must reference an existing storage object. Invalid: ${join(", ", local.vcenters_unknown_iscsi_storage)}"
    }

    precondition {
      condition     = length(local.vcenters_iscsi_storage_router_mismatch) == 0
      error_message = "nested_vsphere vCenter placement.storage.storage must be attached to the same router. Invalid: ${join(", ", local.vcenters_iscsi_storage_router_mismatch)}"
    }

    precondition {
      condition     = length(local.vcenters_unknown_iscsi_lun) == 0
      error_message = "nested_vsphere vCenter placement.storage.lun must reference an existing LUN on placement.storage.storage. Invalid: ${join(", ", local.vcenters_unknown_iscsi_lun)}"
    }

    precondition {
      condition     = length(local.vcenters_missing_iscsi_vmkernel_purposes) == 0
      error_message = "nested_vsphere vCenter iscsi_datastore storage mode must define placement.storage.vmkernel_purposes. Missing: ${join(", ", local.vcenters_missing_iscsi_vmkernel_purposes)}"
    }

    precondition {
      condition     = length(local.vcenters_unknown_iscsi_vmkernel_purposes) == 0
      error_message = "nested_vsphere vCenter placement.storage.vmkernel_purposes must reference purposes on placement.esxi_group vmkernel_adapters. Invalid: ${join(", ", local.vcenters_unknown_iscsi_vmkernel_purposes)}"
    }

    precondition {
      condition     = length(local.vcenters_iscsi_port_binding_multiple_subnets) == 0
      error_message = "nested_vsphere vCenter iscsi_datastore port_binding cannot be enabled across multiple VMkernel adapter subnets. Invalid: ${join(", ", local.vcenters_iscsi_port_binding_multiple_subnets)}"
    }

    precondition {
      condition     = length(local.vcenters_missing_vsan_datastore_name) == 0
      error_message = "nested_vsphere vCenter vsan_bootstrap storage mode must define placement.datastore or placement.storage.vsan.datastore_name. Missing: ${join(", ", local.vcenters_missing_vsan_datastore_name)}"
    }

    precondition {
      condition     = length(local.vcenters_missing_vsan_datacenter) == 0
      error_message = "nested_vsphere vCenter vsan_bootstrap storage mode must define placement.storage.vsan.datacenter for the VCSA_cluster section. Missing: ${join(", ", local.vcenters_missing_vsan_datacenter)}"
    }

    precondition {
      condition     = length(local.vcenters_missing_vsan_cluster) == 0
      error_message = "nested_vsphere vCenter vsan_bootstrap storage mode must define placement.storage.vsan.cluster for the VCSA_cluster section. Missing: ${join(", ", local.vcenters_missing_vsan_cluster)}"
    }

    precondition {
      condition     = length(local.vcenters_missing_vsan_cache_disks) == 0
      error_message = "nested_vsphere vCenter vsan_bootstrap storage mode must define at least one placement.storage.vsan.cache_disks entry. Missing: ${join(", ", local.vcenters_missing_vsan_cache_disks)}"
    }

    precondition {
      condition     = length(local.vcenters_missing_vsan_capacity_disks) == 0
      error_message = "nested_vsphere vCenter vsan_bootstrap storage mode must define at least one placement.storage.vsan.capacity_disks entry. Missing: ${join(", ", local.vcenters_missing_vsan_capacity_disks)}"
    }

    precondition {
      condition     = length(local.vcenters_invalid_vsan_compression_mode) == 0
      error_message = "nested_vsphere vCenter vsan_bootstrap must not set both compression_only and deduplication_and_compression. Invalid: ${join(", ", local.vcenters_invalid_vsan_compression_mode)}"
    }

    precondition {
      condition     = length(local.vcenters_vsan_bootstrap_unknown_vcsa_version) == 0
      error_message = "nested_vsphere vCenter vsan_bootstrap requires VCSA installer 7.0 U2 or later. Could not detect the VCSA version from install_sources URL/path for: ${join(", ", local.vcenters_vsan_bootstrap_unknown_vcsa_version)}"
    }

    precondition {
      condition     = length(local.vcenters_vsan_bootstrap_unsupported_vcsa_version) == 0
      error_message = "nested_vsphere vCenter vsan_bootstrap requires VCSA installer 7.0 U2 or later. Unsupported: ${join(", ", local.vcenters_vsan_bootstrap_unsupported_vcsa_version)}"
    }

    precondition {
      condition     = length(local.vcenters_empty_manages) == 0
      error_message = "Each vcenter must declare at least one managed esxi_group in manages. Missing: ${join(", ", local.vcenters_empty_manages)}"
    }

    precondition {
      condition     = length(local.vcenters_unknown_managed_esxi_groups) == 0
      error_message = "vCenter manages entries must reference existing esxi_groups. Invalid: ${join(", ", local.vcenters_unknown_managed_esxi_groups)}"
    }

    precondition {
      condition     = length(local.vcenters_duplicate_managed_esxi_groups) == 0
      error_message = "Each esxi_group can be managed by at most one vCenter for deployment_v2 ESXi registration. Duplicates: ${join(", ", local.vcenters_duplicate_managed_esxi_groups)}"
    }

    precondition {
      condition     = length(local.vcenters_managed_esxi_group_router_mismatch) == 0
      error_message = "vCenter manages entries must reference esxi_groups attached to the same Router. Invalid: ${join(", ", local.vcenters_managed_esxi_group_router_mismatch)}"
    }

    precondition {
      condition     = length(local.vcenters_missing_network) == 0
      error_message = "vCenter placement.network could not be resolved. Define placement.network or ensure the Router/provider default LAN network is set. Invalid: ${join(", ", local.vcenters_missing_network)}"
    }

    precondition {
      condition     = length(local.vcenters_missing_provider_credentials) == 0
      error_message = "deployment_v2 vCenter prepare requires explicit provider credentials in provider_config. Missing: ${join(", ", local.vcenters_missing_provider_credentials)}"
    }
  }
}
