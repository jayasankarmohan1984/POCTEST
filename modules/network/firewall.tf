# Only resources here — no variable declarations

resource "azurerm_public_ip" "fw_pip" {
  name                = "pip-jtk-fw"
  location            = var.rgs.mgmt.location
  resource_group_name = var.rgs.mgmt.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_firewall" "jtk_fw" {
  name                = "fw-jtk-mgmt"
  location            = var.rgs.mgmt.location
  resource_group_name = var.rgs.mgmt.name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"
  tags                = var.tags

  ip_configuration {
    name                 = "fw-ipconfig"
    subnet_id            = azurerm_subnet.subnet["subnet-mgmt-firewall"].id
    public_ip_address_id = azurerm_public_ip.fw_pip.id
  }
}