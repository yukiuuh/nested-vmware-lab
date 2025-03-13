variable "starting_ip" {
  description = "The starting IP address"
  type        = string
}

variable "count" {
  description = "The number of IP addresses to generate"
  type        = number
}

locals {
  cidr_prefix   = join(".", slice(split(".", var.starting_ip), 0, 3))
  starting_host = tonumber(element(split(".", var.starting_ip), 3))
}

output "ip_list" {
  value = [
    for i in range(var.count) :
    format("%s.%d", local.cidr_prefix, local.starting_host + i)
  ]
}