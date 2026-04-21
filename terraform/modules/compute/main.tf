# ==========================================
# 1. NODE JENKINS (Spesifikasi Sedang: B2s)
# ==========================================
resource "azurerm_network_interface" "jenkins_nic" {
  name                = "nic-jenkins"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.jenkins_subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = var.jenkins_pip_id
  }
}

resource "azurerm_linux_virtual_machine" "jenkins_vm" {
  name                = "jenkins-node"
  resource_group_name = var.resource_group_name
  location            = var.location
  #  size                  = "Standard_B2s"
  size                  = "Standard_B2as_v2"
  admin_username        = var.admin_username
  network_interface_ids = [azurerm_network_interface.jenkins_nic.id]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}

# ==========================================
# 2. NODE DEPLOYMENT (Spesifikasi Kecil: B1s)
# ==========================================
resource "azurerm_network_interface" "target_nic" {
  name                = "nic-target"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.target_subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = var.target_pip_id
  }
}

resource "azurerm_linux_virtual_machine" "target_vm" {
  name                  = "target-node"
  resource_group_name   = var.resource_group_name
  location              = var.location
  size                  = "Standard_B2as_v2"
  admin_username        = var.admin_username
  network_interface_ids = [azurerm_network_interface.target_nic.id]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}