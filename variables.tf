variable "location" {
  description = "Azure region for all resources"
  type        = string
}

variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "tenant_id" {
  description = "Azure tenant ID"
  type        = string
}

variable "rg_names" {
  description = "List of resource group names"
  type        = list(string)
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
}

variable "vnets" {
  description = "Map of VNets with resource group, address space, ddos flag, and subnets"
  type = map(object({
    resource_group = string
    address_space  = list(string)
    #ddos_enabled   = bool
    subnets        = map(string) # subnet_name => CIDR
  }))
}

variable "vpn_gateway_sku" {
  description = "SKU for Azure VPN Gateway (e.g., VpnGw1)"
  type        = string
}

variable "local_network_gateway" {
  description = "On-premises local network gateway details"
  type = object({
    name            = string
    resource_group  = string
    gateway_address = string
    address_space   = list(string)
  })
}

variable "s2s_shared_key" {
  description = "Shared key for site-to-site VPN"
  type        = string
  sensitive   = true
}

variable "storage_accounts" {
  description = "Map of storage accounts"
  type = map(object({
    resource_group            = string
    account_tier              = string
    account_replication_type  = string
    account_kind              = string
    enable_https_traffic_only = bool
  }))
}

########################
# Windows VM variables
########################
variable "vm_size" {
  description = "Size for Windows VMs"
  type        = string
  default     = "Standard_B2ms"
}

variable "win_admin_username" {
  description = "Admin username for Windows VMs"
  type        = string
}

variable "win_admin_password" {
  description = "Admin password for Windows VMs"
  type        = string
  sensitive   = true
}

########################
# Azure Monitor
########################
variable "log_analytics_retention_days" {
  description = "Retention period for Log Analytics workspace"
  type        = number
  default     = 30
}

########################
# Logic App
########################
variable "logic_app_name" {
  description = "Name for Logic App workflow"
  type        = string
  default     = "la-hsc"
}

########################
# Azure Virtual Desktop
########################
variable "avd_max_sessions" {
  description = "Maximum sessions allowed per host pool"
  type        = number
  default     = 20
}