output "jenkins_vm_id" {
  value = azurerm_linux_virtual_machine.jenkins_vm.id
}

output "target_vm_id" {
  value = azurerm_linux_virtual_machine.target_vm.id
}