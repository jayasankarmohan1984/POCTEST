########################
# terraform.tfvars
# Subscription : Hub Subscription (aab79a42-5d6c-4418-b87c-4e3232fde1b1)
# Region       : East US
# NOTE         : Do NOT add win_admin_password or s2s_shared_key here.
#                Those are secret variables managed in Azure DevOps pipeline.
########################

# ── Core ────────────────────────────────────────────────────
location        = "eastus"
subscription_id = "aab79a42-5d6c-4418-b87c-4e3232fde1b1"
tenant_id       = "c55b81ef-8f80-4060-ab39-da01a2578d30"

# ── Workspace / Environment ──────────────────────────────────
environment_override = ""

# ── Resource Groups ─────────────────────────────────────────
rg_names = [
  "RG-NET",
  "RG-MGMT"
]

# ── Tags ────────────────────────────────────────────────────
tags = {
  project     = "hub-poc"
  managed_by  = "terraform"
  environment = "hub"
}

# ── VNets ───────────────────────────────────────────────────
vnets = {
  "VN-VPN-FE" = {
    resource_group = "RG-NET"
    address_space  = ["10.0.0.0/16"]
    subnets = {
      "GatewaySubnet" = "10.0.1.0/27"
      "snet-hub-01"   = "10.0.2.0/24"
    }
  }
}

# ── VPN Gateway ─────────────────────────────────────────────
vpn_gateway_sku = "VpnGw1"

# ── Local Network Gateway (On-Premises) ─────────────────────
local_network_gateway = {
  name            = "lng-onprem"
  resource_group  = "RG-NET"
  gateway_address = "1.2.3.4"          # ← Replace with your on-prem public IP
  address_space   = ["192.168.0.0/16"] # ← Replace with your on-prem CIDR range
}

# ── Storage Accounts ─────────────────────────────────────────
storage_accounts = {
  "tfstateaccountpoc" = {
    resource_group            = "RG-MGMT"
    account_tier              = "Standard"
    account_replication_type  = "LRS"
    account_kind              = "StorageV2"
    enable_https_traffic_only = true
  }
}

# ── Windows VMs ─────────────────────────────────────────────
vm_size            = "Standard_B2ms"
win_admin_username = "adminuser" # ← Replace with your preferred admin username

# ── Azure Monitor ────────────────────────────────────────────
log_analytics_retention_days = 30

# ── Logic App ───────────────────────────────────────────────
logic_app_name = "la-hsc"

# ── Azure Virtual Desktop ───────────────────────────────────
avd_max_sessions = 20

# ─────────────────────────────────────────────────────────────
# ⚠️  SECRETS — DO NOT ADD HERE
# win_admin_password  → Set as secret variable in Azure DevOps pipeline
# s2s_shared_key      → Set as secret variable in Azure DevOps pipeline
# ─────────────────────────────────────────────────────────────
