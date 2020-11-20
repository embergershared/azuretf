#--------------------------------------------------------------
#   Backend TF State, Specific Locals
#--------------------------------------------------------------
terraform {
  backend azurerm {
    subscription_id      = ""
    resource_group_name  = ""
    storage_account_name = ""
    container_name       = "tfstates-demo-aks"
    key                  = "cluster1-3-k8sinfra"
  }
}

locals {
  tf_values = "/subscriptions/demo/3-aks/cluster1/3-k8sinfra"
  tf_state  = "tfstates-demo-aks/cluster1-3-k8sinfra"
}