# Description   : This Terraform Plan creates the Terraform Backend resources in Azure.
#                 It uses a local state that can be manually uploaded after in the container.
#
#                 It deploys:
#                   - a backend resource group
#                   - a storage account for backend purposes
#                   - a container to store the tfstate files
#
#                 To use it, follow these steps:
#                   - Execute CreateTFSP.ps1 to create a Terraform Service Principal in the target subscription
#                   - Execute TerraformKubectlSetup.ps1 to install terraform and kubectl on your Windows machine
#                   - in the folder /hub-spoke-privateaks/1-backend-tflocal/ execute "tf init"
#                   - fill in the *.auto.tfvars.json files with the variables' values
#                   - execute "tf plan"
#                   - check the plan
#                   - execute "tf apply" with the wanted settings
#
# Directory     : /hub-spoke-privateaks/1-backend-tflocal/
# Modules       : none
# Created on    : 2020-03-22
# Created by    : Emmanuel
# Last Modified : 2020-04-01
# Prerequisites : terraform 0.12.+, azurerm 2.2.0

# If changes in BACKEND     : tf init
# To PLAN an execution      : tf plan
# Then to APPLY this plan   : tf apply -auto-approve
# To DESTROY the resources  : tf destroy

# To REMOVE a resource state: tf state rm 'azurerm_storage_container.tfstatecontainer'
# To IMPORT a resource      : tf import azurerm_storage_container.tfstatecontainer /[id]

provider azurerm {
    version         = "=2.2.0"
    features {}
    
    tenant_id       = var.tenant_id
    subscription_id = var.subscription_id
    client_id       = var.tf_app_id
    client_secret   = var.tf_app_secret
    }
locals {
    timestamp = formatdate("YYYY-MM-DD hh:mm ZZZ", timestamp())
    base_tags = "${map(
        "BuiltBy", "Terraform",
        "TfFolder", "/hub-spoke-privateaks/1-backend-tflocal/",
        "BuiltOn","${local.timestamp}",
        "InitiatedBy", "EB",
        "RefreshedOn", "${local.timestamp}",
    )}"
    }

#   ===  Hub Base Services Resource Group  ===
resource azurerm_resource_group "hub_basesvc_rg" {
    name     = "Hub-BaseServices-RG"
    location = "canadacentral"

    tags = local.base_tags
    lifecycle {
        ignore_changes = [
            tags["BuiltOn"],
    ]
    }
    }

#   ===  Hub Base Storage Account  ===
resource azurerm_storage_account "hub_basesvc_storacct" {
    name                        = "hubbasesvcstor"
    location                    = azurerm_resource_group.hub_basesvc_rg.location
    resource_group_name         = azurerm_resource_group.hub_basesvc_rg.name
    account_kind                = "StorageV2"
    account_tier                = "Standard"
    account_replication_type    = "LRS"
    
    tags = local.base_tags
    lifecycle {
        ignore_changes = [
            tags["BuiltOn"],
    ]
    }
    }

#   ===  Terraform states container  ===
resource azurerm_storage_container "tfstatecontainer"   {
    name                  = "terraform-states"
    storage_account_name  = azurerm_storage_account.hub_basesvc_storacct.name
    container_access_type = "private"
    }
