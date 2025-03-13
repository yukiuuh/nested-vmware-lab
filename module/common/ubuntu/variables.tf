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

variable "userdata" {
  default = ""
}

variable "network_interfaces" {
  default = []
}

variable "cdroms" {
  default = [
    {
      datastore_id  = null
      path          = null
      client_device = true
    }
  ]
}

variable "remote_ovf_url" {
  default = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.ova"
}
variable "disks" {
  type = list(object({
    label       = string
    size_gb     = number
    unit_number = number
  }))
}

variable "wait_for_guest_net_routable" {
  default = true
}