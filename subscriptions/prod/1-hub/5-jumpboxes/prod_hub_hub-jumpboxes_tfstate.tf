#--------------------------------------------------------------
#   Backend TF State, Specific Locals
#--------------------------------------------------------------
terraform {
  backend azurerm {
    subscription_id      = ""
    resource_group_name  = ""
    storage_account_name = ""
    container_name       = "tfstates-prod-hub"
    key                  = "5-jumpboxes"
  }
}

locals {
  tf_values = "/subscriptions/prod/1-hub/5-jumpboxes"
  tf_state  = "tfstates-prod-hub/5-jumpboxes"
}