########################
# variables.tf
########################

# ── Core ────────────────────────────────────────────────────
variable "location" {
  description = "Azure region for all resources."
  type        = string
}

variable "subscription_id" {
  description = "Azure subscription ID — __Hub Subscription__ (aab79a42-5d6c-4418-b87c-4e3232fde1b1)."
  type        = string
}

variable "tenant_id" {
  description = "Azure tenant ID (iacpocoutlook.onmicrosoft.com)."
  type        = string
}

# ── Workspace / Environment ──────────────────────────────────
# Derived automatically from terraform.workspace; override only when needed.
variable "environment_override" {
  description = "Override the workspace-derived environment label (e.g. dev, staging, prod)."
  type        = string
  default     = ""
}

# ── Resource Groups ─────────────────────────────────────────
variable "rg_names" {
  description = "List of resource group names to create."
  type        = list(string)
}

# ── Tags ────────────────────────────────────────────────────
variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default     = {}
}

# ── VNets ───────────────────────────────────────────────────
variable "vnets" {
  description = "Map of VNets: resource_group, address_space, subnets (name → CIDR)."
  type = map(object({
    resource_group = string
    address_space  = list(string)
    subnets        = map(string)
  }))
}

# ── VPN Gateway ─────────────────────────────────────────────
variable "vpn_gateway_sku" {
  description = "SKU for Azure VPN Gateway (e.g. VpnGw1, VpnGw2)."
  type        = string
  default     = "VpnGw1"
}

variable "local_network_gateway" {
  description = "On-premises local network gateway details."
  type = object({
    name            = string
    resource_group  = string
    gateway_address = string
    address_space   = list(string)
  })
}

variable "s2s_shared_key" {
  description = "Shared key for site-to-site VPN connection."
  type        = string
  sensitive   = true
}

# ── Storage Accounts ─────────────────────────────────────────
variable "storage_accounts" {
  description = "Map of storage accounts to create."
  type = map(object({
    resource_group            = string
    account_tier              = string
    account_replication_type  = string
    account_kind              = string
    enable_https_traffic_only = bool
    # FIX: field was declared but never consumed in the original resource block;
    # now it is wired to https_traffic_only_enabled in main.tf
  }))
}

# ── Windows VMs ─────────────────────────────────────────────
variable "vm_size" {
  description = "Azure VM size for Windows VMs."
  type        = string
  default     = "Standard_B2ms"
}

variable "win_admin_username" {
  description = "Admin username for Windows VMs."
  type        = string
}

variable "win_admin_password" {
  description = "Admin password for Windows VMs."
  type        = string
  sensitive   = true
}

# ── Azure Monitor ────────────────────────────────────────────
variable "log_analytics_retention_days" {
  description = "Log Analytics workspace retention period in days (min 30, max 730)."
  type        = number
  default     = 30

  validation {
    condition     = var.log_analytics_retention_days >= 30 && var.log_analytics_retention_days <= 730
    error_message = "log_analytics_retention_days must be between 30 and 730."
  }
}

# ── Logic App ───────────────────────────────────────────────
variable "logic_app_name" {
  description = "Name for the Logic App workflow resource."
  type        = string
  default     = "la-hsc"
}

# ── Azure Virtual Desktop ───────────────────────────────────
variable "avd_max_sessions" {
  description = "Maximum sessions per AVD host pool."
  type        = number
  default     = 20

  validation {
    condition     = var.avd_max_sessions >= 1 && var.avd_max_sessions <= 999999
    error_message = "avd_max_sessions must be between 1 and 999999."
  }
}
