# No variable declarations here — only resources

resource "azurerm_public_ip" "bastion_pip" {
  name                = "pip-jtk-bastion"
  location            = var.rgs.mgmt.location
  resource_group_name = var.rgs.mgmt.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_bastion_host" "jtk_bastion" {
  name                = "bastion-jtk-mgmt"
  location            = var.rgs.mgmt.location
  resource_group_name = var.rgs.mgmt.name
  tags                = var.tags

  ip_configuration {
    name                 = "bastion-ipconfig"
    subnet_id            = azurerm_subnet.subnet["subnet-mgmt-jump"].id
    public_ip_address_id = azurerm_public_ip.bastion_pip.id
  }
}