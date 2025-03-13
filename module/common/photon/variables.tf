variable "name" {
  type = string
}

variable "num_cpus" {
  type    = number
  default = 2
}

variable "mem_gb" {
  type    = number
  default = 4
}

variable "vi" {}

variable "metadata" {
  default = ""
}
variable "userdata" {
  default = ""
}
variable "network_interfaces" {
  default = []
}

variable "cdroms" {
  default = []
}
variable "remote_ovf_url" {
  default = "https://packages.vmware.com/photon/5.0/GA/ova/photon-hw15-5.0-dde71ec57.x86_64.ova"
}

variable "wait_for_guest_net_routable" {
  default = true
}