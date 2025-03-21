variable "vsphere_kickstarter_ip" {}

# variable "vsphere_kickstarter_user" { default = "root" }
variable "vsphere_kickstarter_password" { default = "VMware123!" }
# variable "vsphere_kickstarter_www_dir" { default = "/srv/" }

variable "subnet_mask" {
  type    = string
  default = "255.255.255.0"
}
variable "gateway" {}
variable "vm_password" {
}

variable "vi" {}
variable "name" {}
variable "network_interfaces" {
  type = list(string)
}
variable "remote_ovf_url" {
  default = "https://packages.vmware.com/photon/5.0/GA/ova/photon-hw15-5.0-dde71ec57.x86_64.ova"
}

variable "vcsa_iso_datastore" {

}
variable "vcsa_iso_path" {

}

variable "vcsa_name" {}
variable "vcsa_datastore_name" {}
variable "vcsa_deployment_size" { default = "tiny" }
variable "vcsa_network_name" { default = "VM Network" }
# variable "vcsa_pnid" {}
variable "vcsa_hostname" {}
variable "vcsa_ip" {}

variable "vcsa_ssh_enabled" { default = true }
variable "vcsa_subnet_mask" {}
variable "vcsa_nameservers" {}
variable "vcsa_gateway" {}
variable "vcsa_ntp" {}
variable "vcsa_domain_name" {}
variable "vcsa_sso_domain_name" { default = "vsphere.local" }
variable "vcsa_password" { default = "VMware1!" }
variable "vi_esxi_user" { default = "root" }
variable "vi_esxi_host" {}
variable "vi_esxi_password" {}
