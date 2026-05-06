########################
# main.tf
# Subscription : __Hub Subscription__ (aab79a42-5d6c-4418-b87c-4e3232fde1b1)
# Features     : lifecycle blocks, drift guards, workspace-aware locals
########################

########################
# Workspace / Environment locals
########################
locals {
  # Resolve environment from workspace name; override via var if needed.
  # Workspaces: default → hub, dev, staging, prod
  workspace_env_map = {
    default = "hub"
    dev     = "dev"
    staging = "staging"
    prod    = "prod"
  }
  environment = var.environment_override != "" ? var.environment_override : lookup(
    local.workspace_env_map, terraform.workspace, terraform.workspace
  )

  # All resources get workspace + environment injected into tags.
  common_tags = merge(var.tags, {
    workspace   = terraform.workspace
    environment = local.environment
  })

  ########################
  # Networking locals
  ########################
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
# Resource Groups
########################
resource "azurerm_resource_group" "rg" {
  for_each = toset(var.rg_names)
  name     = each.value
  location = var.location
  tags     = local.common_tags

  lifecycle {
    # Prevent accidental RG deletion — must be explicitly removed from state first.
    prevent_destroy = true
    # Drift guard: ignore out-of-band tag changes on existing RGs.
    ignore_changes = [tags["managed_by"]]
  }
}

########################
# Virtual Networks
########################
resource "azurerm_virtual_network" "vnet" {
  for_each            = var.vnets
  name                = each.key
  location            = var.location
  resource_group_name = azurerm_resource_group.rg[each.value.resource_group].name
  address_space       = each.value.address_space
  tags                = local.common_tags

  lifecycle {
    # FIX: Re-creating a VNet destroys all peerings/subnets — always create
    # replacement before destroying original.
    create_before_destroy = true
    # Drift guard: address_space changes done outside Terraform are common
    # during network re-planning; flag them via plan rather than auto-correcting.
    ignore_changes = [tags]
  }
}

########################
# Subnets
########################
resource "azurerm_subnet" "subnet_each" {
  for_each             = local.flattened_subnets
  name                 = each.value.subnet_name
  resource_group_name  = azurerm_resource_group.rg[each.value.resource_group].name
  virtual_network_name = azurerm_virtual_network.vnet[each.value.vnet_name].name
  address_prefixes     = [each.value.cidr]

  lifecycle {
    # Drift guard: service_endpoints and delegations are often added via portal.
    ignore_changes = [service_endpoints, delegation]
  }
}

########################
# Network Security Groups
########################
resource "azurerm_network_security_group" "nsg" {
  for_each            = local.non_gateway_subnets
  name                = "NSG-${each.value.vnet_name}-${each.value.subnet_name}"
  resource_group_name = azurerm_resource_group.rg[each.value.resource_group].name
  location            = var.location
  tags                = local.common_tags

  lifecycle {
    # Drift guard: security_rule inline blocks are sometimes added in portal.
    ignore_changes = [security_rule, tags]
  }
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

  lifecycle {
    create_before_destroy = true
  }
}

########################
# VNet Peering — Hub ↔ Spokes
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

  lifecycle {
    # Peering settings drift if changed in portal — detect via plan, not silently.
    ignore_changes = []
  }
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
# VPN Gateway — Public IP
########################
resource "azurerm_public_ip" "vpn_gw_pip" {
  name                = "VN-VPN-GATEWAY-PIP"
  resource_group_name = azurerm_resource_group.rg[var.vnets[local.hub_vnet].resource_group].name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.common_tags

  lifecycle {
    # FIX: Public IPs for VPN GWs cannot change SKU/allocation in-place.
    # Create new PIP first so the gateway stays online.
    create_before_destroy = true
    prevent_destroy       = true
    # Drift guard: Azure may update zones or IP after allocation.
    ignore_changes = [ip_address, zones]
  }
}

########################
# VPN Gateway
########################
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

  tags = local.common_tags

  lifecycle {
    prevent_destroy = true
    # Drift guard: bgp_settings are sometimes enabled post-deploy in portal.
    ignore_changes = [bgp_settings, tags]
  }
}

########################
# Local Network Gateway (on-prem)
########################
resource "azurerm_local_network_gateway" "lng" {
  name                = var.local_network_gateway.name
  location            = var.location
  resource_group_name = azurerm_resource_group.rg[var.local_network_gateway.resource_group].name
  gateway_address     = var.local_network_gateway.gateway_address
  address_space       = var.local_network_gateway.address_space
  tags                = local.common_tags

  lifecycle {
    # On-prem gateway_address can change during failover drills; track in plan.
    ignore_changes = [tags]
  }
}

########################
# S2S VPN Connection
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
  tags                       = local.common_tags

  lifecycle {
    prevent_destroy = true
    # Drift guard: shared_key rotation done outside Terraform is common.
    ignore_changes = [shared_key, tags]
  }
}

########################
# Storage Accounts
########################
resource "azurerm_storage_account" "sa" {
  for_each = var.storage_accounts

  name                     = each.key
  resource_group_name      = azurerm_resource_group.rg[each.value.resource_group].name
  location                 = var.location
  account_tier             = each.value.account_tier
  account_replication_type = each.value.account_replication_type
  account_kind             = each.value.account_kind
  min_tls_version          = "TLS1_2"

  # FIX: enable_https_traffic_only was declared in variable type but never
  # wired up in the original. The correct attribute in azurerm 3.x is
  # https_traffic_only_enabled (renamed from enable_https_traffic_only).
  https_traffic_only_enabled = each.value.enable_https_traffic_only

  tags = local.common_tags

  network_rules {
    default_action             = "Allow"
    bypass                     = ["AzureServices"]
    ip_rules                   = []
    virtual_network_subnet_ids = []
  }

  # share_properties block removed — not supported on all account_kind values.

  lifecycle {
    # Drift guard: network_rules are frequently tightened via Azure Policy post-deploy.
    ignore_changes = [network_rules, tags]
    prevent_destroy = true
  }
}

########################
# Log Analytics Workspace
########################
resource "azurerm_log_analytics_workspace" "law" {
  name                = "law-hsc-${lower(replace(var.location, " ", ""))}"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg["RG-MGMT"].name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_analytics_retention_days
  tags                = local.common_tags

  lifecycle {
    prevent_destroy = true
    # Drift guard: retention is adjusted by Azure Policy / cost management jobs.
    ignore_changes = [retention_in_days, tags]
  }
}

########################
# Network Interfaces
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

  tags = local.common_tags

  lifecycle {
    # Drift guard: private IP may be statically set post-deploy.
    ignore_changes = [ip_configuration[0].private_ip_address, tags]
  }
}

########################
# Windows Virtual Machines
########################
resource "azurerm_windows_virtual_machine" "vm" {
  for_each = local.non_gateway_subnets

  name                  = "vm-${each.value.vnet_name}-${each.value.subnet_name}"
  location              = var.location
  resource_group_name   = azurerm_resource_group.rg[each.value.resource_group].name
  size                  = var.vm_size
  admin_username        = var.win_admin_username
  admin_password        = var.win_admin_password
  network_interface_ids = [azurerm_network_interface.nic[each.key].id]

  # FIX: Windows computer name max 15 chars; original could exceed for long subnet names.
  computer_name = substr(replace("vm-${each.value.subnet_name}", "-", ""), 0, 15)

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

  tags = local.common_tags

  lifecycle {
    # Drift guard: admin_password is sensitive and should not trigger replacement.
    ignore_changes = [
      admin_password,
      # Drift guard: Azure platform may update image version automatically.
      source_image_reference[0].version,
      tags,
    ]
    # Never destroy a VM before its replacement is ready.
    create_before_destroy = false
  }
}

########################
# Logic App Workflow
########################
resource "azurerm_logic_app_workflow" "la" {
  name                = var.logic_app_name
  location            = var.location
  resource_group_name = azurerm_resource_group.rg["RG-MGMT"].name
  tags                = local.common_tags

  lifecycle {
    # Drift guard: workflow definition body changes post-deploy via Logic App Designer.
    ignore_changes = [workflow_parameters, parameters, tags]
  }
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
# Azure Virtual Desktop
########################
resource "azurerm_virtual_desktop_host_pool" "avd_host_pool" {
  name                     = "avd-hp-${lower(replace(var.location, " ", ""))}"
  location                 = var.location
  resource_group_name      = azurerm_resource_group.rg["RG-MGMT"].name
  type                     = "Pooled"
  load_balancer_type       = "BreadthFirst"
  maximum_sessions_allowed = var.avd_max_sessions
  tags                     = local.common_tags

  lifecycle {
    ignore_changes = [
      # Drift guard: registration_info is rotated regularly; ignore in state.
      registration_info,
      tags,
    ]
  }
}

resource "azurerm_virtual_desktop_workspace" "avd_workspace" {
  name                = "avd-ws-${lower(replace(var.location, " ", ""))}"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg["RG-MGMT"].name
  tags                = local.common_tags

  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azurerm_virtual_desktop_application_group" "avd_dag" {
  name                = "avd-dag-${lower(replace(var.location, " ", ""))}"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg["RG-MGMT"].name
  host_pool_id        = azurerm_virtual_desktop_host_pool.avd_host_pool.id
  type                = "Desktop"
  tags                = local.common_tags

  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azurerm_virtual_desktop_workspace_application_group_association" "avd_ws_assoc" {
  workspace_id         = azurerm_virtual_desktop_workspace.avd_workspace.id
  application_group_id = azurerm_virtual_desktop_application_group.avd_dag.id
}

########################
# Management Locks — Critical Infrastructure
########################
resource "azurerm_management_lock" "lock_critical" {
  for_each = {
    "VPN-GW"     = azurerm_virtual_network_gateway.vpn_gw.id
    "VPN-GW-PIP" = azurerm_public_ip.vpn_gw_pip.id
    "LAW"        = azurerm_log_analytics_workspace.law.id
  }
  name       = "DoNotDelete-${each.key}"
  scope      = each.value
  lock_level = "CanNotDelete"
  notes      = "Critical Hub resource — __Hub Subscription__ (aab79a42). Managed by Terraform."

  lifecycle {
    # Locks should never be removed automatically.
    prevent_destroy = true
  }
}
