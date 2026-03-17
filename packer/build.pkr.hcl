build {
  name = "nvl-unified"
  source "source.vsphere-iso.ubuntu" {
    name = "nvl-unified"
  }
  
  provisioner "shell" {
    scripts = ["scripts/install_pip_packages.sh", "scripts/cleanup.sh"]
  }
}
