#--------------------------------------------------------------
#   Backend TF State, Specific Locals
#--------------------------------------------------------------
terraform {
  backend azurerm {
    subscription_id      = ""
    resource_group_name  = ""
    storage_account_name = ""
    container_name       = "tfstates-prod-hub"
    key                  = "2-logsdiag"
  }
}

locals {
  tf_values = "/subscriptions/prod/1-hub/2-logsdiag"
  tf_state  = "tfstates-prod-hub/2-logsdiag"
}