source "vsphere-iso" "ubuntu" {
  vcenter_server      = var.vsphere_server
  username            = var.vsphere_user
  password            = var.vsphere_password
  insecure_connection = true

  datacenter = var.datacenter
  cluster    = var.cluster
  datastore  = var.datastore
  folder     = var.folder

  guest_os_type        = "ubuntu64Guest"
  vm_name              = var.vm_name
  vm_version           = var.vm_version
  CPUs                 = 2
  RAM                  = 2048
  disk_controller_type = ["pvscsi"]
  storage {
    disk_size             = 10240
    disk_thin_provisioned = true
  }

  network_adapters {
    network      = var.network
    network_card = "vmxnet3"
  }

  iso_url      = var.iso_url
  iso_checksum = var.iso_checksum
  cd_content = {
    "meta-data" = templatefile("${path.root}/http/meta-data.pkrtpl", {
      hostname = var.vm_name
    })
    "user-data" = templatefile("${path.root}/http/user-data.pkrtpl", {
      hostname     = var.vm_name
      ssh_username = var.ssh_username
      ssh_password = bcrypt(var.ssh_password)
    })
  }
  cd_label = "CIDATA"
  
  boot_order = "disk,cdrom"
  boot_wait  = "10s"
  
  boot_command = [
    "c",
    "<wait>",
    "linux /casper/vmlinuz --- autoinstall ds=nocloud;",
    "<enter><wait>",
    "initrd /casper/initrd",
    "<enter><wait>",
    "boot<enter>"
  ]

  ssh_username = var.ssh_username
  ssh_password = var.ssh_password
  ssh_timeout = "60m"
  
  convert_to_template = true

  export {
    force = true
    output_directory = "./output"
  }
}
