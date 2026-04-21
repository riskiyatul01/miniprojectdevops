resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

module "network" {
  source              = "./modules/network"
  resource_group_name = azurerm_resource_group.rg.name     
  location            = azurerm_resource_group.rg.location
  app_port            = var.app_port
}

module "compute" {
  source              = "./modules/compute"
  resource_group_name = module.network.resource_group_name
  location            = module.network.location

  jenkins_subnet_id   = module.network.jenkins_subnet_id
  target_subnet_id    = module.network.target_subnet_id
  jenkins_pip_id      = module.network.jenkins_pip_id
  target_pip_id       = module.network.target_pip_id

  admin_username      = var.admin_username
  ssh_public_key      = var.ssh_public_key
}

resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/template/inventory.tpl", {
    jenkins_ip = module.network.jenkins_public_ip
    target_ip  = module.network.target_public_ip
  })
  filename = "${path.module}/../ansible/inventory/hosts.yml"
}

resource "local_file" "jenkins_target_ip" {
  content  = templatefile("${path.module}/template/target.tpl", {
    target_node_ip = module.network.target_public_ip
  })
  filename = "${path.module}/../ansible/group_vars/target.yml"
}