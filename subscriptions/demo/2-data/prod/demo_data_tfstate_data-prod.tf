#--------------------------------------------------------------
#   Backend TF State, Specific Locals
#--------------------------------------------------------------
terraform {
  backend azurerm {
    subscription_id      = ""
    resource_group_name  = ""
    storage_account_name = ""
    container_name       = "tfstates-demo-data"
    key                  = "prod-1-data"
  }
}

locals {
  tf_values = "/subscriptions/demo/2-data/prod"
  tf_state  = "tfstates-demo-data/prod-1-data"
}