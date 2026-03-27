variable "provider_config" {
  description = "Top-level provider settings for deployment v2"
  type = object({
    server           = optional(string)
    user             = optional(string)
    password         = optional(string)
    datacenter       = string
    resource_pool    = string
    compute_host     = string
    datastore        = string
    default_networks = optional(map(string), {})
  })
}

variable "name_prefix" {
  description = "Prefix applied to VM names created by this deployment"
  type        = string
  default     = "nvl"
}

variable "vm_admin_password" {
  description = "Administrative password used for Router and ESXi guest operations in deployment v2"
  type        = string
  default     = "VMware123!"
  sensitive   = true
}

variable "ssh_authorized_keys" {
  description = "SSH public keys injected into Router VMs"
  type        = list(string)
  default     = []
}

variable "install_sources" {
  description = "Named installation sources"
  type        = map(any)
  default     = {}
}

variable "routers" {
  description = "Named router definitions"
  type        = map(any)
  default     = {}
}

variable "esxi_groups" {
  description = "Named ESXi group definitions"
  type        = map(any)
  default     = {}
}

variable "storages" {
  description = "Named storage service definitions"
  type        = map(any)
  default     = {}
}

variable "vcenters" {
  description = "Named vCenter definitions"
  type        = map(any)
  default     = {}
}

variable "services" {
  description = "Named service definitions"
  type        = map(any)
  default     = {}
}
