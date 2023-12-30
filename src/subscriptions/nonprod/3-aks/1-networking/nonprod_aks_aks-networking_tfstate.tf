#--------------------------------------------------------------
#   Backend TF State, Specific Locals
#--------------------------------------------------------------
terraform {
  backend azurerm {
    subscription_id      = ""
    resource_group_name  = ""
    storage_account_name = ""
    container_name       = "tfstates-aks-networking"
    key                  = "1-networking"
  }
}
locals {
  tf_values = "/subscriptions/azint/3-aks/1-networking"
  tf_state  = "tfstates-aks-networking/1-networking"
}