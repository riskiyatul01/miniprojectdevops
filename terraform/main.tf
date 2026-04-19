module "network" {
  source              = "./modules/network"
  resource_group_name = var.resource_group_name
  location            = var.location
  app_port            = "3000"
}

module "compute" {
  source              = "./modules/compute"
  resource_group_name = module.network.resource_group_name
  location            = var.location
  
  jenkins_subnet_id   = module.network.jenkins_subnet_id
  target_subnet_id    = module.network.target_subnet_id
  jenkins_pip_id      = module.network.jenkins_pip_id
  target_pip_id       = module.network.target_pip_id
  
  admin_username      = var.admin_username
  ssh_public_key      = var.ssh_public_key

  depends_on = [module.network]
}