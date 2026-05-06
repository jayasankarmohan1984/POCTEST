variable "rgs" {
  type = map(object({
    name     = string
    location = string
  }))
}

variable "tags" {
  type = map(string)
}

resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

resource "azurerm_storage_account" "sa" {
  for_each                 = var.rgs
  name                     = "stjtk${lower(replace(each.value.name, "RG-JTK-", ""))}${random_string.suffix.result}"
  resource_group_name      = each.value.name
  location                 = each.value.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"
  tags                     = var.tags

  # ✅ keep network rules here, no need for separate resource
  network_rules {
    default_action             = "Deny"
    bypass                     = ["AzureServices"]
    ip_rules                   = []
    virtual_network_subnet_ids = []
  }
}