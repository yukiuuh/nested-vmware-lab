module "ks_server_address" {
  source     = "../common/netmask2prefix"
  ip_address = var.ks_server_ip
  netmask    = var.subnet_mask
}

locals {
  vm_password        = var.ks_server_password
  photon_spec_path   = "${path.module}/tmp/${var.name}-photon-spec.json"
  deploy_script_path = "${path.module}/tmp/${var.name}-deploy.sh"
  userdata_base64 = base64encode(templatefile("${path.module}/templates/userdata.tftpl",
    {
      password = local.vm_password
  }))
  metadata_base64 = base64encode(templatefile("${path.module}/templates/metadata.tftpl",
    {
      ip_address    = var.ks_server_ip
      subnet_prefix = module.ks_server_address.prefix_length
  }))
  photon_spec_content = templatefile("${path.module}/templates/photon-spec.json.tftpl",
    {
      vm_name      = var.name
      network_name = var.network_interfaces[0]
  })
}
resource "local_file" "photon_spec" {
  content  = local.photon_spec_content
  filename = local.photon_spec_path
}

resource "local_file" "deploy_script" {
  content = templatefile("${path.module}/templates/deploy.sh.tftpl", {
    vm_name           = var.name
    photon_spec_path  = local.photon_spec_path
    photon_ovf_source = var.remote_ovf_url
    userdata_content  = local.userdata_base64
    metadata_content  = local.metadata_base64
    vm_password       = local.vm_password
  })
  filename = local.deploy_script_path
}

resource "terraform_data" "kickstarter_cleanup" {
  input = {
    vm_name        = var.name
    govc_setup_cmd = var.vi.govc_setup_cmd
  }
  provisioner "local-exec" {
    when    = destroy
    command = "${self.input.govc_setup_cmd} govc vm.power -off -force ${self.input.vm_name};${self.input.govc_setup_cmd} govc vm.destroy ${self.input.vm_name}; echo 0"
  }
}

resource "terraform_data" "kickstarter" {
  depends_on = [local_file.deploy_script, local_file.photon_spec]

  lifecycle {
    replace_triggered_by = [local_file.deploy_script, local_file.photon_spec]
  }
  provisioner "local-exec" {
    command = "${var.vi.govc_setup_cmd} bash ${local.deploy_script_path}"
  }
}