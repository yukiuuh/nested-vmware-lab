data "vsphere_datastore" "esxi_install_source_datastore" {
  for_each = {
    for name, source in local.install_sources : name => source
    if try(source.type, "") == "datastore_iso"
  }

  name          = each.value.datastore
  datacenter_id = module.vi.datacenter.id
}

module "esxi_hosts" {
  for_each = local.esxi_group_hosts

  source = "../../module/common/nested_esxi_vm"

  depends_on = [
    terraform_data.validate_esxi_group_inputs,
  ]

  vi = module.vi

  name = format(
    "%s-%s-%s",
    local.deployment_name_prefix,
    each.value.group_name,
    each.value.hostname
  )

  annotation = join(
    "\n",
    [
      "deployment_v2.esxi_group=${each.value.group_name}",
      "deployment_v2.hostname=${each.value.hostname}",
      "deployment_v2.fqdn=${each.value.fqdn}",
      "deployment_v2.ip=${each.value.ip}",
      "deployment_v2.router=${local.esxi_group_runtime[each.value.group_name].router}",
      "deployment_v2.install_source=${local.esxi_group_runtime[each.value.group_name].install.install_source}",
    ]
  )

  num_cpus = local.esxi_group_runtime[each.value.group_name].shape.num_cpus
  mem_gb   = local.esxi_group_runtime[each.value.group_name].shape.mem_gb
  firmware = "efi"

  network_interfaces = [
    for _ in range(local.esxi_group_runtime[each.value.group_name].shape.nic_count) :
    local.esxi_group_runtime[each.value.group_name].network.network_name
  ]

  cdroms = try(local.esxi_group_runtime[each.value.group_name].install.source.type, "") == "datastore_iso" ? [
    {
      datastore_id = data.vsphere_datastore.esxi_install_source_datastore[local.esxi_group_runtime[each.value.group_name].install.install_source].id
      path         = local.esxi_group_runtime[each.value.group_name].install.source.path
    }
  ] : []

  disks = local.esxi_group_runtime[each.value.group_name].shape.disks

  tpm_enabled                = try(local.esxi_group_runtime[each.value.group_name].shape.tpm_enabled, false)
  nvme_enabled               = try(local.esxi_group_runtime[each.value.group_name].shape.nvme_enabled, false)
  memory_reservation_enabled = try(local.esxi_group_runtime[each.value.group_name].shape.memory_reservation_enabled, false)
}
