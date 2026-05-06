########################
# Locals
########################
locals {
  hub_vnet = "VN-VPN-FE"

  subnet_map = {
    for vnet_name, vnet in var.vnets :
    vnet_name => {
      for subnet_name, cidr in vnet.subnets :
      "${vnet_name}|${subnet_name}" => {
        resource_group = vnet.resource_group
        vnet_name      = vnet_name
        subnet_name    = subnet_name
        cidr           = cidr
      }
    }
  }

  flattened_subnets = merge(values(local.subnet_map)...)

  non_gateway_subnets = {
    for k, v in local.flattened_subnets : k => v
    if v.subnet_name != "GatewaySubnet"
  }

  spoke_vnets = [
    for vn in keys(var.vnets) : vn
    if vn != local.hub_vnet
  ]
}

########################
# Resource groups
########################
resource "azurerm_resource_group" "rg" {
  for_each = toset(var.rg_names)
  name     = each.value
  location = var.location
  tags     = var.tags
}

########################
# DDoS protection plan
########################
resource "azurerm_network_ddos_protection_plan" "ddos" {
  name                = "ddos-hsc-${lower(replace(var.location, " ", ""))}"
  resource_group_name = azurerm_resource_group.rg["RG-MGMT"].name
  location            = var.location
  tags                = var.tags
}

########################
# Virtual networks
########################
resource "azurerm_virtual_network" "vnet" {
  for_each            = var.vnets
  name                = each.key
  location            = var.location
  resource_group_name = azurerm_resource_group.rg[each.value.resource_group].name
  address_space       = each.value.address_space

  tags = var.tags
}

########################
# Subnets + NSGs
########################
resource "azurerm_subnet" "subnet_each" {
  for_each             = local.flattened_subnets
  name                 = each.value.subnet_name
  resource_group_name  = azurerm_resource_group.rg[each.value.resource_group].name
  virtual_network_name = azurerm_virtual_network.vnet[each.value.vnet_name].name
  address_prefixes     = [each.value.cidr]
}

resource "azurerm_network_security_group" "nsg" {
  for_each            = local.non_gateway_subnets
  name                = "NSG-${each.value.vnet_name}-${each.value.subnet_name}"
  resource_group_name = azurerm_resource_group.rg[each.value.resource_group].name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_network_security_rule" "deny_internet_inbound" {
  for_each                    = local.non_gateway_subnets
  name                        = "Deny-Internet-Inbound"
  priority                    = 4000
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "Internet"
  destination_address_prefix  = "*"
  network_security_group_name = azurerm_network_security_group.nsg[each.key].name
  resource_group_name         = azurerm_network_security_group.nsg[each.key].resource_group_name
}

resource "azurerm_subnet_network_security_group_association" "assoc" {
  for_each                  = local.non_gateway_subnets
  subnet_id                 = azurerm_subnet.subnet_each[each.key].id
  network_security_group_id = azurerm_network_security_group.nsg[each.key].id
}

########################
# VNet peering (hub <-> spokes)
########################
resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  for_each                  = toset(local.spoke_vnets)
  name                      = "peer-${local.hub_vnet}-to-${each.key}"
  resource_group_name       = azurerm_resource_group.rg[var.vnets[local.hub_vnet].resource_group].name
  virtual_network_name      = azurerm_virtual_network.vnet[local.hub_vnet].name
  remote_virtual_network_id = azurerm_virtual_network.vnet[each.key].id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = true

  depends_on = [azurerm_virtual_network_gateway.vpn_gw]
}

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  for_each                  = toset(local.spoke_vnets)
  name                      = "peer-${each.key}-to-${local.hub_vnet}"
  resource_group_name       = azurerm_resource_group.rg[var.vnets[each.key].resource_group].name
  virtual_network_name      = azurerm_virtual_network.vnet[each.key].name
  remote_virtual_network_id = azurerm_virtual_network.vnet[local.hub_vnet].id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  use_remote_gateways          = true

  depends_on = [azurerm_virtual_network_peering.hub_to_spoke]
}

########################
# VPN gateway (hub)
########################
resource "azurerm_public_ip" "vpn_gw_pip" {
  name                = "VN-VPN-GATEWAY-PIP"
  resource_group_name = azurerm_resource_group.rg[var.vnets[local.hub_vnet].resource_group].name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_virtual_network_gateway" "vpn_gw" {
  name                = "VN-VPN-GATEWAY"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg[var.vnets[local.hub_vnet].resource_group].name
  type                = "Vpn"
  vpn_type            = "RouteBased"
  sku                 = var.vpn_gateway_sku

  ip_configuration {
    name                          = "vpn-gw-ipcfg"
    public_ip_address_id          = azurerm_public_ip.vpn_gw_pip.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.subnet_each["${local.hub_vnet}|GatewaySubnet"].id
  }

  tags = var.tags
}

########################
# Local network gateway (on-prem)
########################
resource "azurerm_local_network_gateway" "lng" {
  name                = var.local_network_gateway.name
  location            = var.location
  resource_group_name = azurerm_resource_group.rg[var.local_network_gateway.resource_group].name
  gateway_address     = var.local_network_gateway.gateway_address
  address_space       = var.local_network_gateway.address_space
  tags                = var.tags
}

########################
# S2S VPN connection
########################
resource "azurerm_virtual_network_gateway_connection" "s2s" {
  name                       = "VN-VPN-VPN-CONNECTION"
  location                   = var.location
  resource_group_name        = azurerm_resource_group.rg[var.vnets[local.hub_vnet].resource_group].name
  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.vpn_gw.id
  local_network_gateway_id   = azurerm_local_network_gateway.lng.id
  shared_key                 = var.s2s_shared_key
  enable_bgp                 = false
  tags                       = var.tags
}

########################
# Storage accounts
########################
resource "azurerm_storage_account" "sa" {
  for_each                 = var.storage_accounts
  name                     = each.key
  resource_group_name      = azurerm_resource_group.rg[each.value.resource_group].name
  location                 = var.location
  account_tier             = each.value.account_tier
  account_replication_type = each.value.account_replication_type
  account_kind             = each.value.account_kind
  min_tls_version          = "TLS1_2"
  tags                     = var.tags

  network_rules {
    default_action             = "Allow"
    bypass                     = ["AzureServices"]
    ip_rules                   = []
    virtual_network_subnet_ids = []
  }

  # Remove the entire share_properties block
}


########################
# Azure Monitor (LAW)
########################

resource "azurerm_log_analytics_workspace" "law" {
  name                = "law-hsc-${lower(replace(var.location, " ", ""))}"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg["RG-MGMT"].name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_analytics_retention_days
  tags                = var.tags
}


########################
# Windows VMs per non-GatewaySubnet
########################
resource "azurerm_network_interface" "nic" {
  for_each            = local.non_gateway_subnets
  name                = "nic-${each.value.vnet_name}-${each.value.subnet_name}"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg[each.value.resource_group].name

  ip_configuration {
    name                          = "ipcfg"
    subnet_id                     = azurerm_subnet.subnet_each[each.key].id
    private_ip_address_allocation = "Dynamic"
  }

  tags = var.tags
}

resource "azurerm_windows_virtual_machine" "vm" {
  for_each              = local.non_gateway_subnets
  name                  = "vm-${each.value.vnet_name}-${each.value.subnet_name}"
  location              = var.location
  resource_group_name   = azurerm_resource_group.rg[each.value.resource_group].name
  size                  = var.vm_size
  admin_username        = var.win_admin_username
  admin_password        = var.win_admin_password
  network_interface_ids = [azurerm_network_interface.nic[each.key].id]

  # Add this line to set a valid short computer name
  computer_name = substr("vm-${each.value.vnet_name}-${each.value.subnet_name}", 0, 15)

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }

  tags = var.tags
}
########################
# Logic App (consumption) with simple HTTP trigger/action
########################
resource "azurerm_logic_app_workflow" "la" {
  name                = var.logic_app_name
  location            = var.location
  resource_group_name = azurerm_resource_group.rg["RG-MGMT"].name
  tags                = var.tags
}

resource "azurerm_logic_app_trigger_http_request" "la_trigger" {
  name         = "http-trigger"
  logic_app_id = azurerm_logic_app_workflow.la.id
  schema       = <<JSON
{
  "type": "object",
  "properties": {
    "message": { "type": "string" }
  }
}
JSON
}

resource "azurerm_logic_app_action_http" "la_action" {
  name         = "http-action"
  logic_app_id = azurerm_logic_app_workflow.la.id
  method       = "POST"
  uri          = "https://example.com/endpoint"
  body         = "{\"status\":\"ok\"}"
  depends_on   = [azurerm_logic_app_trigger_http_request.la_trigger]
}

########################
# Azure Virtual Desktop (control plane scaffold)
########################
resource "azurerm_virtual_desktop_host_pool" "avd_host_pool" {
  name                     = "avd-hp-${lower(replace(var.location, " ", ""))}"
  location                 = var.location
  resource_group_name      = azurerm_resource_group.rg["RG-MGMT"].name
  type                     = "Pooled"
  load_balancer_type       = "BreadthFirst"
  maximum_sessions_allowed = var.avd_max_sessions
  tags                     = var.tags
}

resource "azurerm_virtual_desktop_workspace" "avd_workspace" {
  name                = "avd-ws-${lower(replace(var.location, " ", ""))}"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg["RG-MGMT"].name
  tags                = var.tags
}

resource "azurerm_virtual_desktop_application_group" "avd_dag" {
  name                = "avd-dag-${lower(replace(var.location, " ", ""))}"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg["RG-MGMT"].name
  host_pool_id        = azurerm_virtual_desktop_host_pool.avd_host_pool.id
  type                = "Desktop"
  tags                = var.tags
}

resource "azurerm_virtual_desktop_workspace_application_group_association" "avd_ws_assoc" {
  workspace_id         = azurerm_virtual_desktop_workspace.avd_workspace.id
  application_group_id = azurerm_virtual_desktop_application_group.avd_dag.id
}

########################
# Resource locks for critical infra
########################
resource "azurerm_management_lock" "lock_critical" {
  for_each = {
    "VPN-GW"     = azurerm_virtual_network_gateway.vpn_gw.id
    "VPN-GW-PIP" = azurerm_public_ip.vpn_gw_pip.id
  }
  name       = "DoNotDelete-${each.key}"
  scope      = each.value
  lock_level = "CanNotDelete"
  notes      = "Critical resource per HSC scaffold."
}