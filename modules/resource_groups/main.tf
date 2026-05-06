variable "rgs"  { type = map(object({ name = string, location = string })) }
variable "tags" { type = map(string) }

resource "azurerm_resource_group" "rg" {
  for_each = var.rgs
  name     = each.value.name
  location = each.value.location
  tags     = var.tags
}

output "rg_ids" {
  value = { for k, v in azurerm_resource_group.rg : k => v.id }
}