output "name" {
  value = vsphere_virtual_machine.nested_esxi.name
}

output "mac_addresses" {
  value = [
    for nic in vsphere_virtual_machine.nested_esxi.network_interface :
    nic.mac_address
  ]
}

output "primary_mac_address" {
  value = try(vsphere_virtual_machine.nested_esxi.network_interface[0].mac_address, null)
}
