
########################
# Resource Groups
########################
output "resource_groups" {
  description = "All Resource Groups created."
  value       = keys(azurerm_resource_group.rg)
}

########################
# Virtual Networks
########################
output "vnets" {
  description = "VNet names to IDs."
  value       = { for name, vnet in azurerm_virtual_network.vnet : name => vnet.id }
}

########################
# Subnets
########################
output "subnets" {
  description = "Subnets per VNet."
  value       = { for name, subnet in azurerm_subnet.subnet_each : name => subnet.id }
}

########################
# Network Security Groups
########################
output "nsgs" {
  description = "NSGs per subnet."
  value       = { for name, nsg in azurerm_network_security_group.nsg : name => nsg.id }
}

########################
# VPN Gateway Public IP
########################
output "vpn_gateway_public_ip" {
  description = "Assigned public IP of Azure VPN Gateway."
  value       = azurerm_public_ip.vpn_gw_pip.ip_address
}

########################
# S2S VPN Connection
########################
output "s2s_connection_id" {
  description = "ID of the S2S VPN connection."
  value       = azurerm_virtual_network_gateway_connection.s2s.id
}
