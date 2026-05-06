########################
# outputs.tf
########################

# ── Meta ────────────────────────────────────────────────────
output "workspace" {
  description = "Active Terraform workspace."
  value       = terraform.workspace
}

output "environment" {
  description = "Resolved environment label for this workspace."
  value       = local.environment
}

output "subscription_id" {
  description = "Azure subscription ID in use."
  value       = var.subscription_id
}

# ── Resource Groups ─────────────────────────────────────────
output "resource_groups" {
  description = "All Resource Group names created."
  value       = keys(azurerm_resource_group.rg)
}

# ── Virtual Networks ─────────────────────────────────────────
output "vnets" {
  description = "Map of VNet name → resource ID."
  value       = { for name, vnet in azurerm_virtual_network.vnet : name => vnet.id }
}

# ── Subnets ──────────────────────────────────────────────────
output "subnets" {
  description = "Map of subnet key (vnet|subnet) → resource ID."
  value       = { for name, subnet in azurerm_subnet.subnet_each : name => subnet.id }
}

# ── NSGs ─────────────────────────────────────────────────────
output "nsgs" {
  description = "Map of NSG key → resource ID."
  value       = { for name, nsg in azurerm_network_security_group.nsg : name => nsg.id }
}

# ── VPN Gateway ─────────────────────────────────────────────
output "vpn_gateway_public_ip" {
  description = "Public IP address assigned to the Azure VPN Gateway."
  value       = azurerm_public_ip.vpn_gw_pip.ip_address
}

output "vpn_gateway_id" {
  description = "Resource ID of the VPN Gateway."
  value       = azurerm_virtual_network_gateway.vpn_gw.id
}

# ── S2S Connection ───────────────────────────────────────────
output "s2s_connection_id" {
  description = "Resource ID of the S2S VPN connection."
  value       = azurerm_virtual_network_gateway_connection.s2s.id
}

# ── Storage Accounts ─────────────────────────────────────────
output "storage_account_ids" {
  description = "Map of storage account name → resource ID."
  value       = { for k, sa in azurerm_storage_account.sa : k => sa.id }
}

# ── Log Analytics ────────────────────────────────────────────
output "log_analytics_workspace_id" {
  description = "Resource ID of the Log Analytics Workspace."
  value       = azurerm_log_analytics_workspace.law.id
}

output "log_analytics_workspace_key" {
  description = "Primary shared key for the Log Analytics Workspace."
  value       = azurerm_log_analytics_workspace.law.primary_shared_key
  sensitive   = true
}

# ── Logic App ───────────────────────────────────────────────
output "logic_app_id" {
  description = "Resource ID of the Logic App workflow."
  value       = azurerm_logic_app_workflow.la.id
}

# ── AVD ──────────────────────────────────────────────────────
output "avd_host_pool_id" {
  description = "Resource ID of the AVD Host Pool."
  value       = azurerm_virtual_desktop_host_pool.avd_host_pool.id
}

output "avd_workspace_id" {
  description = "Resource ID of the AVD Workspace."
  value       = azurerm_virtual_desktop_workspace.avd_workspace.id
}
