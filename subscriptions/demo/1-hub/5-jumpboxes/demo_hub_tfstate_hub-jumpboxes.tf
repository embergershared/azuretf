#--------------------------------------------------------------
#   Backend TF State, Specific Locals
#--------------------------------------------------------------
terraform {
  backend azurerm {
    subscription_id      = ""
    resource_group_name  = ""
    storage_account_name = ""
    container_name       = "tfstates-demo-hub"
    key                  = "5-jumpboxes"
  }
}

locals {
  tf_values = "/subscriptions/demo/1-hub/5-jumpboxes"
  tf_state  = "tfstates-demo-hub/5-jumpboxes"
}