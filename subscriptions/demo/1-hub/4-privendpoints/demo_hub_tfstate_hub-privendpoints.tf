#--------------------------------------------------------------
#   Backend TF State, Specific Locals
#--------------------------------------------------------------
terraform {
  backend azurerm {
    subscription_id      = ""
    resource_group_name  = ""
    storage_account_name = ""
    container_name       = "tfstates-demo-hub"
    key                  = "4-privendpoints"
  }
}

locals {
  tf_values = "/subscriptions/demo/1-hub/4-privendpoints"
  tf_state  = "tfstates-demo-hub/4-privendpoints"
}