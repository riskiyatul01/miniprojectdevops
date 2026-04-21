output "resource_group_name" {
  value       = azurerm_resource_group.rg.name
  description = "Nama Resource Group"
}

output "jenkins_public_ip" {
  value = module.network.jenkins_public_ip
}

output "target_public_ip" {
  value = module.network.target_public_ip
}