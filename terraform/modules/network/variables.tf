variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "app_port" {
  type = string
}

variable "allowed_jenkins" {
  type    = string
  default = "*"
}

variable "allowed_target" {
  type    = string
  default = "*"
}