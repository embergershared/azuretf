#--------------------------------------------------------------
#   Backend TF State, Specific Locals
#--------------------------------------------------------------
terraform {
  backend azurerm {
    subscription_id      = ""
    resource_group_name  = ""
    storage_account_name = ""
    container_name       = "tfstates-prod-hub"
    key                  = "4-privendpoints"
  }
}

locals {
  tf_values = "/subscriptions/prod/1-hub/4-privendpoints"
  tf_state  = "tfstates-prod-hub/4-privendpoints"
}