# Description   : This Terraform Plan creates the Hub Backend resources in Azure.
#
#                 It uses a local state that can be then uploaded after in the container
#                 by uncommenting the AzureRM Backend block
#
#                 It deploys:
#                   - a 1 LogDiag resource groups in main location
#                   - in this Backend Resource Group:
#                     - 1 Storage Account in CAC
#                     - 1 Storage Account in CAE
#                     - 1 Log Analytics Workspace
#
# Folder/File   : /tf-plans/1-hub/2-logsdiag/main.tf
# Terraform     : 0.12.+
# Providers     : azurerm 2.+
# Plugins       : none
# Modules       : none
#
# Created on    : 2020-07-25
# Created by    : Emmanuel
# Last Modified : 2020-09-03
# Last Modif by : Emmanuel

#--------------------------------------------------------------
#   Provider, locals
#--------------------------------------------------------------
terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
  }
  required_version = ">= 0.13"
}
provider azurerm {
  version         = "~> 2.12"
  features {}
    
  tenant_id       = var.tenant_id
  subscription_id = var.subscription_id
  client_id       = var.tf_app_id
  client_secret   = var.tf_app_secret
}

locals {
  # Dates formatted
  now = timestamp()
  nowUTC = formatdate("YYYY-MM-DD hh:mm ZZZ", local.now) # 2020-06-16 14:44 UTC
  nowFormatted = "${formatdate("YYYY-MM-DD", local.now)}T${formatdate("hh:mm:ss", local.now)}Z" # "2029-01-01T01:01:01Z"

  # Tags values
  tf_plan   = "/tf-plans/1-hub/2-logsdiag"

  base_tags = "${map(
    "BuiltBy", "Terraform",
    "TfPlan", "${local.tf_plan}/main_hub-logsdiag.tf",
    "TfValues", "${local.tf_values}/",
    "TfState", "${local.tf_state}",
    "BuiltOn","${local.nowUTC}",
    "InitiatedBy", "EB",
  )}"

  # Location short for Main location
  shortl_main_location  = lookup({
      canadacentral   = "cac", 
      canadaeast      = "cae",
      eastus          = "use" },
    lower(var.main_location), "")
}


#--------------------------------------------------------------
#   Logs & Diagnostics Resource Group
#--------------------------------------------------------------
#   / Resource Group
resource azurerm_resource_group logdiag_rg {
  name     = lower("rg-${local.shortl_main_location}-${var.subs_nickname}-hub-logsdiag")
  location = var.main_location

  tags = merge(local.base_tags, "${map(
    "RefreshedOn", "${local.nowUTC}",
  )}")
  lifecycle { ignore_changes = [tags["BuiltOn"]] }
}

#--------------------------------------------------------------
#   Logs & Diagnostics / Storage Accounts
#--------------------------------------------------------------
#   / Canada Central
resource azurerm_storage_account cac_stdiag_storacct {
  name                        = replace(lower("stcac${var.subs_nickname}logsdiag"), "-", "")
  location                    = "canadacentral"
  resource_group_name         = azurerm_resource_group.logdiag_rg.name
  account_kind                = "StorageV2"
  account_tier                = "Standard"
  account_replication_type    = "LRS"
  
  tags = local.base_tags
  lifecycle { ignore_changes = [ tags ] }
}
#   / Canada East
resource azurerm_storage_account cae_stdiag_storacct {
  name                        = replace(lower("stcae${var.subs_nickname}logsdiag"), "-", "")
  location                    = "canadaeast"
  resource_group_name         = azurerm_resource_group.logdiag_rg.name
  account_kind                = "StorageV2"
  account_tier                = "Standard"
  account_replication_type    = "LRS"
    
  tags = local.base_tags
  lifecycle { ignore_changes = [ tags ] }
}

#   / US East for CloudShell
resource azurerm_storage_account use_stdiag_storacct {
  # Limit 3 to 24 chars, numbers & lowercase letters
  name                        = replace(lower("stuse${var.subs_nickname}logsdiag"), "-", "")
  resource_group_name         = azurerm_resource_group.logdiag_rg.name
  location                    = "eastus"          # enforced rule for cloudshell storage
  account_tier                = "Standard"
  account_kind                = "StorageV2"
  account_replication_type    = "LRS"
    
  tags = merge(local.base_tags, "${map(
      "ms-resource-usage","azure-cloud-shell",    # enforced rule for cloudshell storage
  )}")
  lifecycle { ignore_changes = [ tags ] }
}

#--------------------------------------------------------------
#   Logs & Diagnostics / Log Analytics Workspace
#--------------------------------------------------------------
#   / Log Analytics Workspace
resource azurerm_log_analytics_workspace hub_laws {
  name                = lower("log-cac-${var.subs_nickname}-${var.hub_laws_name}")
  resource_group_name = azurerm_resource_group.logdiag_rg.name
  location            = "canadacentral"   # This service is not available in Canada East
  sku                 = "Free"            # Default is "PerGB2018"
  retention_in_days   = var.retention_days

  tags = local.base_tags
  lifecycle { ignore_changes = [ tags ] }
}