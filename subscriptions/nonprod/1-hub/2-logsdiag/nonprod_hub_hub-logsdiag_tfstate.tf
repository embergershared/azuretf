#--------------------------------------------------------------
#   Backend TF State, Specific Locals
#--------------------------------------------------------------
terraform {
  backend azurerm {
    subscription_id      = ""
    resource_group_name  = ""
    storage_account_name = ""
    container_name       = "tfstates-nonprod-hub"
    key                  = "2-logsdiag"
  }
}

locals {
  tf_values = "/subscriptions/nonprod/1-hub/2-logsdiag"
  tf_state  = "tfstates-nonprod-hub/2-logsdiag"
}