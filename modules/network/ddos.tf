# No variable declarations here — only resources

resource "azurerm_network_ddos_protection_plan" "jtk_ddos" {
  name                = "ddos-jtk-plan"
  location            = var.rgs.mgmt.location
  resource_group_name = var.rgs.mgmt.name
  tags                = var.tags
}

resource "azurerm_virtual_network" "vnet_ddos" {
  for_each            = var.vnets
  name                = each.value.name
  location            = var.rgs[each.key].location
  resource_group_name = var.rgs[each.key].name
  address_space       = [each.value.address]
  ddos_protection_plan {
    id     = azurerm_network_ddos_protection_plan.jtk_ddos.id
    enable = true
  }
  tags       = var.tags
  depends_on = [azurerm_network_ddos_protection_plan.jtk_ddos]
}