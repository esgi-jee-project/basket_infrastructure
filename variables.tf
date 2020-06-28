variable "az_count" {
  description = "Number of AZs to cover in a given region"
  default = 2
}

variable "container_env" {
  type = map
  default = {}
}

variable "prefix" {
  description = "Prefix name for all ressources"
}