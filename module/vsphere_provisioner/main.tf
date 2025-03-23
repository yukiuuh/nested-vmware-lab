terraform {
  required_providers {
    ansible = {
      source  = "ansible/ansible"
      version = "1.3.0"
    }
  }
}

resource "random_id" "uuid" {
  byte_length = 4
}
locals {
  name_prefix = random_id.uuid.hex
}
resource "local_file" "private_key" {
  content         = var.ssh_private_key_openssh
  filename        = "/tmp/${local.name_prefix}.pem"
  file_permission = "0600"
}

resource "terraform_data" "wait_for_nested_vsphere" {
  # wait for vCenter Server Appliance to be ready
  connection {
    type             = "ssh"
    host             = var.ip
    user             = var.username
    password         = var.password
    bastion_host     = var.bastion_ip
    bastion_user     = var.bastion_user
    bastion_password = var.bastion_password
  }

  provisioner "file" {
    source      = var.local_govc_path
    destination = "/usr/bin/govc"
  }
  provisioner "remote-exec" {
    inline = [
      "#!/bin/bash",
      "chmod +x /usr/bin/govc",
      "export GOVC_INSECURE=true",
      "export GOVC_URL=${var.vcsa_ip}",
      "export GOVC_USERNAME=${var.vcsa_username}",
      "export GOVC_PASSWORD=${var.vcsa_password}",
      "until govc ls; do sleep 60; done",
      "govc about"
    ]
  }
}

locals {
  ansible_connection_args = var.bastion_ip != null ? "-o ProxyCommand=\"ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ${local_file.private_key.filename} ${var.bastion_user}@${var.bastion_ip} -W %h:%p \" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" : "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
}

resource "ansible_playbook" "provision_nested_vsphere" {
  playbook   = "${path.module}/../../playbooks/vsphere.yaml"
  name       = var.ip
  replayable = true
  depends_on = [terraform_data.wait_for_nested_vsphere]
  verbosity  = 1
  extra_vars = {
    vc_address              = var.vcsa_ip
    vc_username             = var.vcsa_username
    vc_password             = var.vcsa_password
    datacenter_name         = var.nested_datacenter_name
    cluster_name            = var.nested_cluster_name
    esxi_hosts              = jsonencode(var.nested_esxi[*].hostname)
    esxi_password           = var.nested_esxi[0].password
    dvs_list                = jsonencode(var.dvs_list)
    ha_enabled              = var.ha_enabled ? "True" : "False"
    vsan_enabled            = var.vsan_enabled ? "True" : "False"
    drs_enabled             = var.drs_enabled ? "True" : "False"
    ansible_hostname        = var.ip
    ansible_connection      = "ssh"
    ansible_ssh_pass        = var.password
    ansible_user            = var.username
    ansible_ssh_common_args = local.ansible_connection_args
  }
}
