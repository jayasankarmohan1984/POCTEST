resource "azurerm_log_analytics_workspace" "law" {
  name                = "log-jtk-monitor"
  location            = var.rgs["mgmt"].location
  resource_group_name = var.rgs["mgmt"].name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

resource "azurerm_log_analytics_solution" "vm_insights" {
  solution_name        = "VMInsights"
  location             = azurerm_log_analytics_workspace.law.location
  resource_group_name  = azurerm_log_analytics_workspace.law.resource_group_name

  # ✅ Required in new provider versions
  workspace_resource_id = azurerm_log_analytics_workspace.law.id

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/VMInsights"
  }
}