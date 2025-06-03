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
  key_name = random_id.uuid.hex
}
resource "local_file" "private_key" {
  content         = var.ssh_private_key_openssh
  filename        = "/tmp/${local.key_name}.pem"
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

resource "terraform_data" "wait_for_ssh_connection" {
  depends_on = [terraform_data.wait_for_nested_vsphere]

  provisioner "local-exec" {
    command = "until sshpass -p '${var.password}' ssh ${local.ansible_connection_args} ${var.username}@${var.ip} exit; do sleep 15; done"
  }
}

resource "ansible_playbook" "provision_nested_vsphere" {
  playbook   = "${path.module}/../../playbooks/vsphere.yaml"
  name       = var.ip
  replayable = false
  depends_on = [terraform_data.wait_for_ssh_connection]
  verbosity  = 1
  extra_vars = {
    vc_address           = var.vcsa_ip
    vc_username          = var.vcsa_username
    vc_password          = var.vcsa_password
    datacenter_name      = var.nested_datacenter_name
    cluster_name         = var.nested_cluster_name
    esxi_hosts           = jsonencode(var.nested_esxi[*].hostname)
    esxi_password        = var.nested_esxi[0].password
    dvs_list             = jsonencode(var.dvs_list)
    ha_enabled           = var.ha_enabled ? "True" : "False"
    vsan_enabled         = var.vsan_enabled ? "True" : "False"
    drs_enabled          = var.drs_enabled ? "True" : "False"
    storage_policy_list  = jsonencode(var.storage_policy_list)
    content_library_list = jsonencode(var.content_library_list)

    ansible_hostname        = var.ip
    ansible_connection      = "ssh"
    ansible_ssh_pass        = var.password
    ansible_user            = var.username
    ansible_ssh_common_args = local.ansible_connection_args
  }
}

locals {
  nsx_managers = var.nsx != null ? [for m in var.nsx.managers : ({
    ip       = m.ip
    hostname = m.hostname
    vmname   = "${var.name_prefix}-${m.hostname}"
  })] : []
  nsx_edges = var.nsx != null ? [for e in var.nsx.edge_vm_list : ({
    management_ip = e.management_ip
    hostname      = e.hostname
    t0_interfaces = e.t0_interfaces
    vmname        = "${var.name_prefix}-${e.hostname}"
  })] : []
}

resource "ansible_playbook" "deploy_nsx" {
  playbook   = "${path.module}/../../playbooks/deploy_nsx_manager.yaml"
  count      = var.nsx != null ? 1 : 0
  name       = var.ip
  replayable = false
  depends_on = [ansible_playbook.provision_nested_vsphere]
  verbosity  = 1
  extra_vars = {
    vc_address                  = var.vcsa_ip
    vc_username                 = var.vcsa_username
    vc_password                 = var.vcsa_password
    datacenter_name             = var.nested_datacenter_name
    cluster_name                = var.nested_cluster_name
    datastore_name              = var.nested_datastore_name
    management_portgroup_name   = var.nested_management_portroup_name
    nsx_manager1                = jsonencode(local.nsx_managers[0])
    nsx_username                = var.nsx.username
    ntp_server                  = var.ntp
    dns_server                  = var.nameservers[0]
    gateway                     = var.gateway
    netmask                     = var.subnet_mask
    domain_name                 = var.domain_name
    nsx_ova                     = var.nsx.manager_ova
    nsx_ova_path                = var.nsx.manager_ova_path
    nsx_username                = var.nsx.username
    nsx_password                = var.nsx.password
    ovftool_path                = var.ovftool_path
    nsx_manager_deployment_size = var.nsx.manager_deployment_size

    ansible_hostname        = var.ip
    ansible_connection      = "ssh"
    ansible_ssh_pass        = var.password
    ansible_user            = var.username
    ansible_ssh_common_args = local.ansible_connection_args
  }
}


resource "ansible_playbook" "provision_nsx_manager" {
  playbook   = "${path.module}/../../playbooks/provision_nsx_manager.yaml"
  count      = var.nsx != null ? 1 : 0
  name       = var.ip
  replayable = false
  depends_on = [ansible_playbook.deploy_nsx]
  verbosity  = 1
  extra_vars = {
    vc_address                 = var.vcsa_ip
    vc_username                = var.vcsa_username
    vc_password                = var.vcsa_password
    nsx_hostname               = local.nsx_managers[0].ip
    nsx_username               = var.nsx.username
    nsx_password               = var.nsx.password
    nsx_transport_cluster_name = var.nested_cluster_name

    nsx_tep_ip_pool_gateway     = var.nsx.host_tep_ip_pool_gateway
    nsx_tep_ip_pool_start_ip    = var.nsx.host_tep_ip_pool_start_ip
    nsx_tep_ip_pool_end_ip      = var.nsx.host_tep_ip_pool_end_ip
    nsx_tep_ip_pool_cidr        = var.nsx.host_tep_ip_pool_cidr
    nsx_tep_uplink_vlan         = var.nsx.host_tep_uplink_vlan
    nsx_host_switch_uplink_list = jsonencode(var.nsx.host_switch_uplink_list)
    nsx_host_switch_name        = var.nsx.host_switch_name
    nsx_license                 = var.nsx.license

    ansible_hostname        = var.ip
    ansible_connection      = "ssh"
    ansible_ssh_pass        = var.password
    ansible_user            = var.username
    ansible_ssh_common_args = local.ansible_connection_args
  }
}

resource "ansible_playbook" "deploy_edge" {
  playbook   = "${path.module}/../../playbooks/deploy_nsx_edge.yaml"
  count      = var.nsx != null ? 1 : 0
  name       = var.ip
  replayable = false
  depends_on = [ansible_playbook.provision_nsx_manager]
  verbosity  = 1
  extra_vars = {
    vc_address   = var.vcsa_ip
    vc_username  = var.vcsa_username
    vc_password  = var.vcsa_password
    nsx_hostname = var.nsx.managers[0].ip
    nsx_username = var.nsx.username
    nsx_password = var.nsx.password

    datacenter_name           = var.nested_datacenter_name
    cluster_name              = var.nested_cluster_name
    datastore_name            = var.nested_datastore_name
    management_portgroup_name = var.nested_management_portroup_name

    ntp_server  = var.ntp
    dns_server  = var.nameservers[0]
    gateway     = var.gateway
    netmask     = var.subnet_mask
    domain_name = var.domain_name

    edge_deployment_size = var.nsx.edge_deployment_size
    edge_vm_list         = jsonencode(local.nsx_edges)
    nsx_t0_gateway       = var.nsx.t0_gateway
    external_uplink_vlan = var.nsx.external_uplink_vlan

    edge_tep_ip_pool_gateway  = var.nsx.edge_tep_ip_pool_gateway
    edge_tep_ip_pool_start_ip = var.nsx.edge_tep_ip_pool_start_ip
    edge_tep_ip_pool_end_ip   = var.nsx.edge_tep_ip_pool_end_ip
    edge_tep_ip_pool_cidr     = var.nsx.edge_tep_ip_pool_cidr
    edge_tep_uplink_vlan      = var.nsx.edge_tep_uplink_vlan
    nsx_host_switch_name      = var.nsx.host_switch_name
    # external_uplink_vlan_list = var.nsx.external_uplink_vlan_list

    ansible_hostname        = var.ip
    ansible_connection      = "ssh"
    ansible_ssh_pass        = var.password
    ansible_user            = var.username
    ansible_ssh_common_args = local.ansible_connection_args
  }
}

resource "ansible_playbook" "deploy_avi" {
  playbook   = "${path.module}/../../playbooks/deploy_avi.yaml"
  count      = var.avi != null ? 1 : 0
  name       = var.ip
  replayable = false
  depends_on = [ansible_playbook.deploy_edge]
  verbosity  = 1
  extra_vars = {
    vc_address                   = var.vcsa_ip
    vc_username                  = var.vcsa_username
    vc_password                  = var.vcsa_password
    avi_hostname                 = var.avi.controllers[0].hostname
    avi_vm_name                  = "${var.name_prefix}-${var.avi.controllers[0].hostname}"
    avi_username                 = "admin"
    avi_password                 = var.avi.password
    avi_default_password         = var.avi.default_password
    avi_ova_path                 = var.avi.controller_ova_url
    avi_management_ip            = var.avi.controllers[0].ip
    avi_network_list             = jsonencode(var.avi.networks)
    avi_gateway                  = var.avi.gateway
    avi_ipam_usable_network_list = jsonencode(var.avi.ipam_usable_networks)

    ovftool_path = var.ovftool_path

    datacenter_name           = var.nested_datacenter_name
    cluster_name              = var.nested_cluster_name
    datastore_name            = var.nested_datastore_name
    management_portgroup_name = var.nested_management_portroup_name

    ntp_server  = var.ntp
    dns_server  = var.nameservers[0]
    gateway     = var.gateway
    netmask     = var.subnet_mask
    domain_name = var.domain_name

    ansible_hostname        = var.ip
    ansible_connection      = "ssh"
    ansible_ssh_pass        = var.password
    ansible_user            = var.username
    ansible_ssh_common_args = local.ansible_connection_args
  }
}