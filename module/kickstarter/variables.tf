variable "ks_server_ip" {}

# variable "ks_server_user" { default = "root" }
variable "ks_server_password" { default = "VMware123!" }
# variable "ks_server_www_dir" { default = "/srv/" }

variable "subnet_mask" {
  type    = string
  default = "255.255.255.0"
}
# variable "gateway" {}
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
