########################
# Terraform & Provider Versions
# Updated: Hub Subscription aab79a42-5d6c-4418-b87c-4e3232fde1b1
########################
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.116.0" # Latest stable 3.x — 3.90 is EOL for several resources
    }
  }

  # ── Remote backend (workspace-aware) ─────────────────────────────────
  # Values supplied via backend.hcl; key is workspace-stamped at init time.
  # Run:  terraform init -backend-config=backend.hcl -reconfigure
  backend "azurerm" {}
}
