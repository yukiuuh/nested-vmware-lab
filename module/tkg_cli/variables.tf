variable "ubuntu_ovf_url" { default = null }
variable "vm_password" { default = "VMware123!" }

variable "network_name" { type = string }

variable "vi" {}
variable "name" {}

variable "tanzu_cli_url" {
  default = "https://github.com/vmware-tanzu/tanzu-cli/releases/download/v1.5.3/tanzu-cli-linux-amd64.tar.gz"
}
variable "kubectl_url" {
  default = "https://dl.k8s.io/release/v1.33.2/bin/linux/amd64/kubectl"
}

variable "ssh_authorized_keys" {
  default = []
  type    = list(string)
}

variable "ssh_rsa_private" {}
variable "ssh_rsa_public" {}
