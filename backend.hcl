# backend.hcl — partial backend config supplied at `terraform init`
# Usage:
#   terraform init -backend-config=backend.hcl -reconfigure
#
# The state key is overridden per-workspace inside versions.tf / pipeline.
# Subscription: __Hub Subscription__ (aab79a42-5d6c-4418-b87c-4e3232fde1b1)

resource_group_name  = "RG-MGMT"
storage_account_name = "hscstorageacct01"
container_name       = "tfstate"

# Workspace-specific key — each workspace gets its own state file.
# terraform.workspace is NOT interpolatable here; the pipeline stamps
# the key via -backend-config="key=hub/<workspace>/terraform.tfstate"
key = "hub/default/terraform.tfstate"
