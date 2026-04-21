output "resource_group_name" { 
  value = var.resource_group_name 
  description = "Nama Resource Group"
}

output "location" { 
  value = var.location 
  description = "Lokasi Resource Group"
}

output "jenkins_subnet_id" {
  value       = azurerm_subnet.jenkins_subnet.id
  description = "ID Subnet VM Jenkins"
}

output "target_subnet_id" {
  value       = azurerm_subnet.target_subnet.id
  description = "ID Subnet VM Target Deploy"
}

output "jenkins_public_ip" {
  value       = azurerm_public_ip.jenkins_pip.ip_address
  description = "IP Publik Jenkins"
}

output "target_public_ip" {
  value       = azurerm_public_ip.target_pip.ip_address
  description = "IP Publik App"
}

output "jenkins_pip_id" {
  value       = azurerm_public_ip.jenkins_pip.id
  description = "ID IP Publik Jenkins"
}

output "target_pip_id" {
  value       = azurerm_public_ip.target_pip.id
  description = "ID IP Publik App"
}