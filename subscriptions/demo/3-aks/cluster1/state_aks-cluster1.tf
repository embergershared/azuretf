#--------------------------------------------------------------
#   Backend TF State, Specific Locals
#--------------------------------------------------------------
terraform {
  backend azurerm {
    subscription_id      = ""
    resource_group_name  = ""
    storage_account_name = ""
    container_name       = "terraform-states"
    key                  = "3-aks-cluster1-2-cluster"
  }
}
locals {
  tf_values = "/subscriptions/demo/3-aks/cluster1"
  tf_state  = "3-aks-cluster1-2-cluster"
}