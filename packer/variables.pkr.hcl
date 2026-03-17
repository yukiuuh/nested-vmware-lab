packer {
  required_plugins {
    vsphere = {
      version = ">= 2.0.0"
      source  = "github.com/hashicorp/vsphere"
    }
  }
}

variable "vsphere_server" {
  type    = string
  default = ""
}

variable "vsphere_user" {
  type    = string
  default = ""
}

variable "vsphere_password" {
  type      = string
  sensitive = true
  default   = ""
}

variable "datacenter" {
  type    = string
  default = ""
}

variable "cluster" {
  type    = string
  default = ""
}

variable "datastore" {
  type    = string
  default = ""
}

variable "network" {
  type    = string
  default = "VM Network"
}

variable "folder" {
  type    = string
  default = "Templates"
}

variable "iso_url" {
  type    = string
  default = "https://releases.ubuntu.com/24.04/ubuntu-24.04.3-live-server-amd64.iso"
}

variable "iso_checksum" {
  type    = string
  default = "file:https://releases.ubuntu.com/24.04/SHA256SUMS"
}

variable "http_ip" {
  type    = string
  default = ""
}

variable "vm_name" {
  type    = string
  default = "ubuntu-base"
}

variable "ssh_username" {
  type    = string
  default = "labadmin"
}

variable "ssh_password" {
  type      = string
  sensitive = true
  default   = "VMware123!"
}

variable "vm_version" {
  type    = number
  default = 19
}
