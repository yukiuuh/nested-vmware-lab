output "resource_pool" {
  value = data.vsphere_resource_pool.resource_pool
}
output "compute_host" {
  value = data.vsphere_host.compute_host
}
output "datastore" {
  value = data.vsphere_datastore.datastore
}
output "datacenter" {
  value = data.vsphere_datacenter.datacenter
}
output "networks" {
  value = data.vsphere_network.networks
}
output "govc_setup_cmd" {
  value = (
    var.vsphere_server != null && var.vsphere_user != null && var.vsphere_password != null
  ) ? "GOVC_URL=${"https://${var.vsphere_user}:${urlencode(var.vsphere_password)}@${var.vsphere_server}"} GOVC_INSECURE=true GOVC_DATACENTER=${var.datacenter} GOVC_DATASTORE=${var.datastore} GOVC_RESOURCE_POOL=${var.resource_pool}" : null
}

output "govc_url" {
  value = (
    var.vsphere_server != null && var.vsphere_user != null && var.vsphere_password != null
  ) ? "https://${var.vsphere_user}:${urlencode(var.vsphere_password)}@${var.vsphere_server}" : null
}
