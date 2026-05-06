########################
# Provider Configuration
# Subscription : __Hub Subscription__ (aab79a42-5d6c-4418-b87c-4e3232fde1b1)
# Directory    : Default Directory (iacpocoutlook.onmicrosoft.com)
# Tenant ID    : derived from var.tenant_id
########################

provider "azurerm" {
  features {
    resource_group {
      # Prevent accidental deletion of non-empty RGs
      prevent_deletion_if_contains_resources = true
    }
    virtual_machine {
      # Do NOT delete OS disk automatically when VM is destroyed
      delete_os_disk_on_deletion     = false
      graceful_shutdown              = true
      skip_shutdown_and_force_delete = false
    }
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
    log_analytics_workspace {
      permanently_delete_on_destroy = false
    }
  }

  subscription_id = var.subscription_id # aab79a42-5d6c-4418-b87c-4e3232fde1b1 in tfvars
  tenant_id       = var.tenant_id       # iacpocoutlook.onmicrosoft.com directory
}
