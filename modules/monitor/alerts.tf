# No variable or data declarations here — only resources

resource "azurerm_monitor_action_group" "jtk_action_group" {
  name                = "ag-jtk-alerts"
  resource_group_name = var.rgs.mon.name
  short_name          = "jtkag"
  email_receiver {
    name          = "platform-team"
    email_address = "platform-team@example.com"
  }
  tags = var.tags
}

resource "azurerm_monitor_metric_alert" "vm_cpu_high" {
  for_each            = { for k, v in var.rgs : k => v if k != "mon" }
  name                = "alert-jtk-${each.value.name}-vm-cpu-high"
  resource_group_name = var.rgs.mon.name
  scopes              = ["/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${each.value.name}"]
  description         = "Alert when VM CPU exceeds 80% for 5 minutes"
  severity            = 2
  frequency           = "PT1M"
  window_size         = "PT5M"
  auto_mitigate       = true
  enabled             = true

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "Percentage CPU"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
    dimension {
      name     = "ResourceId"
      operator = "Include"
      values   = ["*"]
    }
  }

  action {
    action_group_id = azurerm_monitor_action_group.jtk_action_group.id
  }

  tags = var.tags
}

resource "azurerm_monitor_activity_log_alert" "security_events" {
  name                = "alert-jtk-activity-security"
  resource_group_name = var.rgs.mon.name
  scopes              = ["/subscriptions/${data.azurerm_client_config.current.subscription_id}"]
  description         = "Alert on role assignment changes"
  enabled             = true

  criteria {
    category       = "Administrative"
    operation_name = "Microsoft.Authorization/roleAssignments/write"
    level          = "Warning"
  }

  action {
    action_group_id = azurerm_monitor_action_group.jtk_action_group.id
  }

  tags = var.tags
}