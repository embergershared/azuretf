# Description   : This Terraform file is used to:
#
#
# Directory     : /
# Modules       : none
# Created on    : 2020-04-20
# Created by    : 
# Last Modified : 2020-04-20
# Prerequisites : terraform 0.12.+, azurerm 2.2.0

# Note: the use of *auto.tfvars* pattern allow variables files auto processing
# If changes in BACKEND     : tf init
# To PLAN an execution      : tf plan
# Then to APPLY this plan   : tf apply -auto-approve
# To DESTROY the resources  : tf destroy

# To REMOVE a resource state: tf state rm 'azurerm_storage_container.tfstatecontainer'
# To IMPORT a resource      : tf import azurerm_storage_container.tfstatecontainer /[id]

terraform {
  backend "azurerm" {
    subscription_id      = "subscription_id"
    resource_group_name  = "resource_group_name"
    storage_account_name = "storage_account_name"
    container_name       = "container_name"
    key                  = "tfstatefilename"
    }
    }
provider azurerm {
    version         = "=2.2.0"
    features        {}

    tenant_id       = var.tenant_id
    subscription_id = var.subscription_id
    client_id       = var.tf_app_id
    client_secret   = var.tf_app_secret
    }
