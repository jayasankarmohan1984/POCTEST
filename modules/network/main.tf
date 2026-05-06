variable "rgs" {
  type = map(object({ name = string, location = string }))
}

variable "vnets" {
  type = any
}

variable "rdp_allowed_source" {
  type = string
}

variable "tags" {
  type = map(string)
}

# VNets
resource "azurerm_virtual_network" "vnet" {
  for_each            = var.vnets
  name                = each.value.name
  location            = var.rgs[each.key].location
  resource_group_name = var.rgs[each.key].name
  address_space       = [each.value.address]
  tags                = var.tags
}

# Flatten subnets into a local map
locals {
  subnet_map = {
    for subnet in flatten([
      for vnet_key, vnet in var.vnets : [
        for subnet_key, cidr in vnet.subnets : {
          key        = "subnet-${vnet_key}-${subnet_key}"
          vnet_key   = vnet_key
          subnet_key = subnet_key
          vnet_name  = vnet.name
          rg_name    = var.rgs[vnet_key].name
          cidr       = cidr
        }
      ]
    ]) : subnet.key => subnet
  }
}

resource "azurerm_subnet" "subnet" {
  for_each = local.subnet_map

  name                 = "snet-jtk-${each.value.vnet_key}-${each.value.subnet_key}"
  resource_group_name  = each.value.rg_name
  virtual_network_name = each.value.vnet_name
  address_prefixes     = [each.value.cidr]
}

# NSGs
resource "azurerm_network_security_group" "nsg" {
  for_each            = azurerm_subnet.subnet
  name                = "nsg-jtk-${each.value.vnet_name}-${each.value.subnet_key}"
  location            = var.rgs[each.value.vnet_key].location
  resource_group_name = each.value.rg_name
  tags                = var.tags

  security_rule {
    name                       = "Allow-RDP-Inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = var.rdp_allowed_source
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-VNet-Inbound"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "Deny-All-Inbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "assoc" {
  for_each                  = azurerm_subnet.subnet
  subnet_id                 = each.value.id
  network_security_group_id = azurerm_network_security_group.nsg[each.key].id
}

# Hub-spoke peering
resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  for_each = { for k, v in azurerm_virtual_network.vnet : k => v if k != "mgmt" }

  name                         = "peer-jtk-mgmt-to-${each.key}"
  resource_group_name          = var.rgs["mgmt"].name
  virtual_network_name         = azurerm_virtual_network.vnet["mgmt"].name
  remote_virtual_network_id    = each.value.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
}

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  for_each = { for k, v in azurerm_virtual_network.vnet : k => v if k != "mgmt" }

  name                         = "peer-jtk-${each.key}-to-mgmt"
  resource_group_name          = var.rgs[each.key].name
  virtual_network_name         = each.value.name
  remote_virtual_network_id    = azurerm_virtual_network.vnet["mgmt"].id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  use_remote_gateways          = false
}

output "vnet_names" {
  value = { for k, v in azurerm_virtual_network.vnet : k => v.name }
}

output "subnet_names" {
  value = {
    for k, v in var.vnets :
    k => keys(v.subnets)
  }
}