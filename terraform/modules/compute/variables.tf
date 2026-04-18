variable "resource_group_name" { type = string }
variable "location" { type = string }

variable "jenkins_subnet_id" { type = string }
variable "target_subnet_id" { type = string }
variable "jenkins_pip_id" { type = string }
variable "target_pip_id" { type = string }

variable "admin_username" {
  type    = string
  default = "ubuntu"
}
variable "ssh_public_key" {
  type        = string
  description = "Isi file .pub SSH Key"
}