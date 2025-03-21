locals {
  ks_template_path = "${path.module}/kickstart/8.0.tftpl"
  ks = templatefile(local.ks_template_path,
    {
      password             = var.password
      ip                   = var.management_vmknic.ip
      netmask              = var.management_vmknic.subnet
      vlan                 = var.management_vmknic.vlan
      gateway              = var.management_vmknic.gateway
      hostname             = var.hostname
      nameserver           = var.dns
      ntp                  = var.ntp
      ssh_enabled          = var.ssh_enabled
      nfs_hosts            = var.nfs_hosts
      iscsi_targets        = var.iscsi_targets
      mtu                  = var.management_vmknic.mtu
      storage1_vmknic      = var.storage1_vmknic
      storage2_vmknic      = var.storage2_vmknic
      provision_datastores = var.provision_datastores
    }
  )

  vtpms = var.tpm_enabled ? [1] : []

  filter_extra_config = merge({ for i in range(length(var.network_interfaces)) :
  "ethernet${tostring(i)}.filter4.name" => "dvfilter-maclearn" })
  filter_on_failure_extra_config = merge({ for i in range(length(var.network_interfaces)) :
  "ethernet${tostring(i)}.filter4.onFailure" => "failOpen" })
  esxi_url = "https://root:${urlencode(var.password)}@${var.management_vmknic.ip}/sdk"
}

data "vsphere_datastore" "iso_datastore" {
  name          = var.iso_datastore
  datacenter_id = var.vi.datacenter.id
}

resource "terraform_data" "kickstart_script" {
  connection {
    type             = "ssh"
    user             = var.ks_server_user
    password         = var.ks_server_password
    host             = var.ks_server_ip
    bastion_host     = var.bastion_ip
    bastion_user     = var.bastion_user
    bastion_password = var.bastion_password
  }
  provisioner "file" {
    content     = local.ks
    destination = "/tmp/${var.name}.cfg"
  }
  provisioner "remote-exec" {
    inline = [
      "${var.ks_server_user == "root" ? "" : "sudo"} cp /tmp/${var.name}.cfg ${var.ks_server_www_dir}"
    ]
  }
}

resource "vsphere_virtual_machine" "nested_esxi" {
  depends_on            = [terraform_data.kickstart_script]
  name                  = var.name
  num_cpus              = var.num_cpus
  num_cores_per_socket  = var.num_cpus
  memory                = var.mem_gb * 1024
  datastore_id          = var.vi.datastore.id
  resource_pool_id      = var.vi.resource_pool.id
  host_system_id        = var.vi.compute_host.id
  guest_id              = var.guest_id
  firmware              = "efi"
  scsi_type             = "pvscsi"
  nested_hv_enabled     = true
  hardware_version      = var.hardware_version
  annotation            = "Provisioned from [${var.iso_datastore}] ${var.iso_path}"
  nvme_controller_count = 1
  force_power_off       = true
  enable_disk_uuid      = true

  lifecycle {
    ignore_changes = [
      vapp[0].properties,
      host_system_id,
      disk[0].io_share_count,
      disk[1].io_share_count,
      disk[2].io_share_count,
      cdrom[0]
    ]
  }

  dynamic "network_interface" {
    for_each = var.network_interfaces
    content {
      network_id = var.vi.networks[network_interface.value].id
    }
  }

  dynamic "disk" {
    for_each = var.disks
    content {
      label           = disk.value.label
      size            = disk.value.size_gb
      unit_number     = disk.value.unit_number
      controller_type = var.nvme_enabled ? "nvme" : "scsi"
    }
  }

  dynamic "vtpm" {
    for_each = local.vtpms
    content {
      version = "2.0"
    }
  }

  cdrom {
    datastore_id = data.vsphere_datastore.iso_datastore.id
    path         = var.iso_path
  }

  wait_for_guest_net_timeout  = var.wait_for_guest_net_timeout
  wait_for_guest_ip_timeout   = var.wait_for_guest_ip_timeout
  wait_for_guest_net_routable = var.wait_for_guest_net_routable

  extra_config_reboot_required = false

  extra_config = merge(local.filter_extra_config, local.filter_on_failure_extra_config)

  provisioner "local-exec" {
    command = "${var.vi.govc_setup_cmd} VM_NAME=${var.name} flock /tmp/enter_boot_option bash ${path.module}/scripts/enter_boot_option.sh"
  }
  provisioner "local-exec" {
    command = "${var.vi.govc_setup_cmd} KS_URL=http://${var.ks_server_ip}/${var.name}.cfg KS_NAMESERVER=${var.dns} KS_IP=${var.management_vmknic.ip} KS_NETMASK=${var.management_vmknic.subnet} KS_GATEWAY=${var.management_vmknic.gateway} VM_NAME=${var.name} KS_VLAN=${var.management_vmknic.vlan} bash ${path.module}/scripts/enter_kickstart.sh"
  }
  provisioner "local-exec" {
    command = "until govc guest.ls -l 'root:${var.password}' -vm ${var.name} /var/tmp/provisioned ; do sleep 60 ; done"
    environment = {
      GOVC_URL        = var.vi.govc_url
      GOVC_INSECURE   = "true"
      GOVC_DATACENTER = var.vi.datacenter.name
    }
  }
}
