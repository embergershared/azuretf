#--------------------------------------------------------------
#   Backend TF State, Specific Locals
#--------------------------------------------------------------
terraform {
  backend azurerm {
    subscription_id      = ""
    resource_group_name  = ""
    storage_account_name = ""
    container_name       = "terraform-states"
    key                  = "1-hub-3-sharedsvc"
  }
}

locals {
  tf_values = "/subscriptions/demo/1-hub/3-sharedsvc"
  tf_state  = "1-hub-3-sharedsvc"
}