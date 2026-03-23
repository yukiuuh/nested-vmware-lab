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

  esxi_groups_unsupported_placement = [
    for name, group in local.esxi_groups : "${name}:${try(group.placement.kind, "unset")}"
    if !contains(local.supported_esxi_group_placements, try(group.placement.kind, ""))
  ]

  esxi_groups_unsupported_boot_mode = [
    for name, group in local.esxi_groups : "${name}:${try(group.boot.mode, "unset")}"
    if !contains(local.supported_esxi_boot_modes, try(group.boot.mode, ""))
  ]

  esxi_groups_unsupported_install_method = [
    for name, group in local.esxi_groups : "${name}:${try(group.install.method, "unset")}"
    if !contains(local.supported_esxi_install_methods, try(group.install.method, ""))
  ]

  esxi_groups_unsupported_kickstart_template = [
    for name, group in local.esxi_groups : "${name}:${try(group.install.pxe.ks_template, "unset")}"
    if try(group.install.pxe.ks_template, null) != null
    && !contains(local.supported_esxi_kickstart_templates, try(group.install.pxe.ks_template, ""))
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
      error_message = "Router placement.kind currently supports only physical_vsphere. Invalid: ${join(", ", local.routers_unsupported_placement)}"
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
      error_message = "ESXi install_source type must currently be http_iso or rclone_iso. Invalid: ${join(", ", local.esxi_groups_invalid_install_source_type)}"
    }

    precondition {
      condition     = length(local.esxi_groups_unsupported_placement) == 0
      error_message = "ESXi placement.kind currently supports only physical_vsphere. Invalid: ${join(", ", local.esxi_groups_unsupported_placement)}"
    }

    precondition {
      condition     = length(local.esxi_groups_unsupported_boot_mode) == 0
      error_message = "ESXi boot.mode currently supports only pxe. Invalid: ${join(", ", local.esxi_groups_unsupported_boot_mode)}"
    }

    precondition {
      condition     = length(local.esxi_groups_unsupported_install_method) == 0
      error_message = "ESXi install.method currently supports only ansible_router_pxe. Invalid: ${join(", ", local.esxi_groups_unsupported_install_method)}"
    }

    precondition {
      condition     = length(local.esxi_groups_unsupported_kickstart_template) == 0
      error_message = "ESXi install.pxe.ks_template currently supports only esxi-8.0. Invalid: ${join(", ", local.esxi_groups_unsupported_kickstart_template)}"
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
  }
}
