# Route tables for all VNets except mgmt
resource "azurerm_route_table" "rt_spoke" {
  for_each            = { for k, v in var.vnets : k => v if k != "mgmt" }
  name                = "rt-jtk-${each.key}-to-fw"
  location            = var.rgs[each.key].location
  resource_group_name = var.rgs[each.key].name
  tags                = var.tags

  route {
    name                   = "fw-default"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.jtk_fw.ip_configuration[0].private_ip_address
  }
}

# Subnet associations, filtered correctly
resource "azurerm_subnet_route_table_association" "assoc" {
  for_each = {
    for k, v in azurerm_subnet.subnet :
    k => v if contains(keys(var.vnets), v.vnet_key) && v.vnet_key != "mgmt"
  }

  subnet_id      = each.value.id
  route_table_id = azurerm_route_table.rt_spoke[each.value.vnet_key].id
}