#--------------------------------------------------------------
#   Backend TF State, Specific Locals
#--------------------------------------------------------------
terraform {
  backend azurerm {
    subscription_id      = ""
    resource_group_name  = ""
    storage_account_name = ""
    container_name       = "tfstates-nonprod-aks"
    key                  = "cluster1-6-diag"
  }
}

locals {
  tf_values = "/subscriptions/nonprod/3-aks/cluster1/4-diag"
  tf_state  = "tfstates-nonprod-aks/cluster1-6-diag"
}