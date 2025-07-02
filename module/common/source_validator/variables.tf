variable "ova_urls" {
  type = list(string)
}

variable "datastore_files" {
  type = list(object(
    {
      path           = string
      datastore_name = string
    }
  ))
}
variable "vi" {}