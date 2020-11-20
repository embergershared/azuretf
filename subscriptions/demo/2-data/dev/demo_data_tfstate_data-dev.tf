#--------------------------------------------------------------
#   Backend TF State, Specific Locals
#--------------------------------------------------------------
terraform {
  backend azurerm {
    subscription_id      = ""
    resource_group_name  = ""
    storage_account_name = ""
    container_name       = "tfstates-demo-data"
    key                  = "dev-1-data"
  }
}

locals {
  tf_values = "/subscriptions/demo/2-data/dev"
  tf_state  = "tfstates-demo-data/dev-1-data"
}