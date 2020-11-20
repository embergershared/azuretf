#--------------------------------------------------------------
#   Backend TF State, Specific Locals
#--------------------------------------------------------------
terraform {
  backend azurerm {
    subscription_id      = ""
    resource_group_name  = ""
    storage_account_name = ""
    container_name       = "tfstates-demo-aks"
    key                  = "cluster1-2-cluster"
  }
}

locals {
  tf_values = "/subscriptions/demo/3-aks/cluster1/2-cluster"
  tf_state  = "tfstates-demo-aks/cluster1-2-cluster"
}