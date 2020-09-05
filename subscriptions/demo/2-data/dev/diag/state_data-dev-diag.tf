#--------------------------------------------------------------
#   Backend TF State, Specific Locals
#--------------------------------------------------------------
terraform {
  backend azurerm {
    subscription_id      = ""
    resource_group_name  = ""
    storage_account_name = ""
    container_name       = "terraform-states"
    key                  = "2-data-dev-2diag"
  }
}

locals {
  tf_values = "/subscriptions/demo/2-data/dev/diag"
  tf_state  = "2-data-dev-2diag"
}