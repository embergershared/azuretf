# Description   : This Terraform Plan is used to:
#                 Create backend resources, tracked in the AzureRm Backend state
#                 It deploys in the Backend RG:
#                   - a storage account for Cloud Shell storage
#                   - a Log Analytics Workspace
#
# Directory     : /hub-spoke-privateaks/2-backend-tfremote/
# Modules       : none
# Created on    : 2020-03-22
# Created by    : Emmanuel
# Last Modified : 2020-04-01
# Prerequisites : terraform 0.12.+, azurerm 2.2.0

# Note: the use of *auto.tfvars* pattern allow variables files auto processing
# If changes in backend    : tf init
# Use with this cmdline    : tf plan
# Then apply with that cmd : tf apply -auto-approve
# To Destroy the infra     : tf destroy

#   ===  Provider and Backend Storage  ===
terraform {
  backend "azurerm" {
    resource_group_name  = "Hub-BaseServices-RG"
    storage_account_name = "hubbasesvcstor"
    container_name       = "terraform-states"
    key                  = "2-backend-tfremote.tfstate"
    }
    }
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
        "TfFolder", "/hub-spoke-privateaks/2-backend-tfremote/",
        "BuiltOn","${local.timestamp}",
        "InitiatedBy", "EB",
        "RefreshedOn", "${local.timestamp}",        
    )}"
    }

#   ===  Reference to the Backend Resource Group  ===
data azurerm_resource_group "hub_basesvc_rg" {
    name     = "Hub-BaseServices-RG"
    }

#   ===  Storage Account for CloudShell commands  ===
resource azurerm_storage_account "cloudshellstore" {
    name                        = "hubcloudshellstor"
    resource_group_name         = data.azurerm_resource_group.hub_basesvc_rg.name
    location                    = "eastus"          # enforced rule for cloudshell storage
    account_tier                = "Standard"
    account_kind                = "StorageV2"
    account_replication_type    = "LRS"
    
    tags = merge(local.base_tags, "${map(
        "ms-resource-usage","azure-cloud-shell",    # enforced rule for cloudshell storage
    )}")
    lifecycle {
        ignore_changes = [
            tags["BuiltOn"],
        ]
    }
    }

#   ===  Log Analytics Workspace  ===
resource "azurerm_log_analytics_workspace" "hub-laws" {
    name                = "Hub-LogAnalyticsWorkspace"
    resource_group_name = data.azurerm_resource_group.hub_basesvc_rg.name
    location            = data.azurerm_resource_group.hub_basesvc_rg.location
    sku                 = "Free" # Default is "PerGB2018"
    #retention_in_days   = 30

    tags = local.base_tags
    lifecycle {
        ignore_changes = [
            tags["BuiltOn"],
        ]
    }
    }