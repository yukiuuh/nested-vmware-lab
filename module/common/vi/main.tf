data "vsphere_datacenter" "datacenter" {
  name = var.datacenter
}
data "vsphere_resource_pool" "resource_pool" {
  name          = var.resource_pool
  datacenter_id = data.vsphere_datacenter.datacenter.id
}
data "vsphere_host" "compute_host" {
  name          = var.compute_host
  datacenter_id = data.vsphere_datacenter.datacenter.id
}
data "vsphere_datastore" "datastore" {
  name          = var.datastore
  datacenter_id = data.vsphere_datacenter.datacenter.id
}
data "vsphere_network" "networks" {
  for_each      = var.networks
  name          = each.value
  datacenter_id = data.vsphere_datacenter.datacenter.id
}
