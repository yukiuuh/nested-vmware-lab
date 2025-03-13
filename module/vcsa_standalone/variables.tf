variable "vi" {}
variable "installer_name" {}
variable "installer_ip" {}
variable "deployment_option" { default = "tiny" }

variable "vcsa_iso_datastore" {}
variable "vcsa_iso_path" {}

variable "name" {}
variable "datastore_name" {}
variable "network_name" { default = "VM Network" }
variable "ip" {}
variable "ssh_enabled" { default = true }
variable "subnet_mask" {}
variable "nameservers" { default = [] }
variable "gateway" {}
variable "ntp" {}
variable "sso_domain_name" { default = "vsphere.local" }
variable "domain_name" { nullable = true }
variable "hostname" { nullable = true }
variable "pnid" { nullable = true }
variable "remote_ovf_url" {}

variable "vm_password" { default = "VMware1!" }

