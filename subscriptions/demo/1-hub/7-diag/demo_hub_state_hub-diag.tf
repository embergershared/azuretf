#--------------------------------------------------------------
#   Backend TF State, Specific Locals
#--------------------------------------------------------------
terraform {
  backend azurerm {
    subscription_id      = ""
    resource_group_name  = ""
    storage_account_name = ""
    container_name       = "tfstates-demo-hub"
    key                  = "7-diag"
  }
}

locals {
  tf_values = "/subscriptions/demo/1-hub/7-diags"
  tf_state  = "tfstates-azint-hub/7-diag"
}