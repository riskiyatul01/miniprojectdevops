variable "resource_group_name" {
  type    = string
  default = "ets-devops-03"
}

variable "location" {
  type    = string
  default = "Indonesia Central"
}

variable "app_port" {
  type    = string
  default = "3000"
}

variable "ssh_public_key" {
  type = string
}

variable "admin_username" {
  type    = string
  default = "ubuntu"
}