variable "az_count" {
  description = "Number of AZs to cover in a given region"
}

variable "app_port" {
  description = "Port exposed by the docker image to redirect traffic to"
  default     = 8080
}

variable "vpc" {
  description = "VPC object"
}

variable "private_subnet" {
  description = "VPC private subnet"
}

variable "public_subnet" {
  description = "VPC public subnet"
}

variable "availability_zone" {
  description = "Availability zone"
}


variable "prefix" {
  description = "Prefix name for all ressources"
}

variable "task_definition_path" {
  description = "Path for the task definition"
}

variable "public_subnet_depends_on" {
  type    = any
  default = null
}

variable "container_env" {
  type = map
  default = {}
}
