resource "terraform_data" "vcenter_destroy_cleanup" {
  for_each = {
    for name, vcenter in local.vcenter_runtime : name => vcenter
    if vcenter.placement.kind == "provider_vsphere"
  }

  input = {
    vm_name         = each.value.name
    target_hostname = each.value.target.hostname
    target_username = each.value.target.username
    target_password = each.value.target.password
    datacenter      = try(each.value.target.datacenter, null)
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["/bin/bash", "-lc"]
    command     = <<-EOT
      set -euo pipefail

      if ! command -v govc >/dev/null 2>&1; then
        echo "govc not found; skipping deployment_v2 vCenter destroy cleanup for ${self.input.vm_name}" >&2
        exit 0
      fi

      export GOVC_URL=${jsonencode("https://${self.input.target_hostname}")}
      export GOVC_USERNAME=${jsonencode(self.input.target_username)}
      export GOVC_PASSWORD=${jsonencode(self.input.target_password)}
      export GOVC_INSECURE="1"

      datacenter=${jsonencode(self.input.datacenter != null ? self.input.datacenter : "")}
      if [ -z "$${datacenter}" ]; then
        echo "target datacenter is empty; skipping deployment_v2 vCenter destroy cleanup for ${self.input.vm_name}" >&2
        exit 0
      fi

      search_root="/$${datacenter}/vm"
      mapfile -t matches < <(govc find "$${search_root}" -type m -name "${self.input.vm_name}" 2>/dev/null || true)
      if [ "$${#matches[@]}" -eq 0 ]; then
        exit 0
      fi

      govc vm.destroy "$${matches[@]}"
    EOT
  }
}
