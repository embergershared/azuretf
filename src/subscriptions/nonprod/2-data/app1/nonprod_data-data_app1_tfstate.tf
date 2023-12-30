#--------------------------------------------------------------
#   Backend TF State, Specific Locals
#--------------------------------------------------------------
terraform {
  backend azurerm {
    subscription_id      = ""
    resource_group_name  = ""
    storage_account_name = ""
    container_name       = "tfstates-nonprod-data"
    key                  = "app1-data"
  }
}

locals {
  tf_values = "/subscriptions/nonprod/2-data/app1"
  tf_state  = "tfstates-nonprod-data/app1-data"
}