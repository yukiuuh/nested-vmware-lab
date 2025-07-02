resource "terraform_data" "check_datastore_files" {
  count = length(var.datastore_files)
  provisioner "local-exec" {
    command = "govc datastore.ls ${var.datastore_files[count.index].path}"
    environment = {
      GOVC_URL        = nonsensitive(var.vi.govc_url)
      GOVC_INSECURE   = "true"
      GOVC_DATACENTER = var.vi.datacenter.name
      GOVC_DATASTORE  = var.datastore_files[count.index].datastore_name
    }
  }
}

resource "terraform_data" "check_ova_urls" {
  count = length(var.ova_urls)
  provisioner "local-exec" {
    command = "govc import.spec ${var.ova_urls[count.index]}"
    environment = {
      GOVC_URL        = nonsensitive(var.vi.govc_url)
      GOVC_INSECURE   = "true"
      GOVC_DATACENTER = var.vi.datacenter.name
    }
  }
}
