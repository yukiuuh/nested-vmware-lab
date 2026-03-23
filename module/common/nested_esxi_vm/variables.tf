variable "vi" {}

variable "name" {
  type = string
}

variable "num_cpus" {
  type = number
}

variable "mem_gb" {
  type = number
}

variable "guest_id" {
  type    = string
  default = "vmkernel65Guest"
}

variable "firmware" {
  type    = string
  default = "efi"
}

variable "hardware_version" {
  default  = null
  nullable = true
}

variable "annotation" {
  type    = string
  default = null
}

variable "network_interfaces" {
  type = list(string)
}

variable "disks" {
  type = list(object({
    label       = string
    size_gb     = number
    unit_number = number
  }))
}

variable "tpm_enabled" {
  type    = bool
  default = false
}

variable "nvme_enabled" {
  type    = bool
  default = false
}

variable "memory_reservation_enabled" {
  type    = bool
  default = false
}
