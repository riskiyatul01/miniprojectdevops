variable "resource_group_name" {
  type        = string
  default     = "ets-devops-03"
  description = "Nama Resource Group"
}

variable "location" {
  type        = string
  default     = "Southeast Asia"
}

variable "app_port" {
  type        = string
  default     = "3000"
}

variable "allowed_jenkins" {
  type        = string
  default     = "*"
}

variable "allowed_target" {
  type        = string
  default     = "*"
}