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
#                     - 1 Log Analytics Solution ContainersInsights
#
# Folder/File   : /tf-plans/1-hub/2-logsdiag/main.tf
# Terraform     : 0.12.+
# Providers     : azurerm 2.+
# Plugins       : none
# Modules       : none
#
# Created on    : 2020-07-25
# Created by    : Emmanuel
# Last Modified : 2020-09-19
# Last Modif by : Emmanuel
# Modif desc.   : Added Log Analytics Solution ContainerInsights


#--------------------------------------------------------------
#   Plan's Locals
#--------------------------------------------------------------
module main_loc {
  source    = "../../../../modules/shortloc"
  location  = var.main_location
}
locals {
  # Plan Tag value
  tf_plan   = "/tf-plans/1-hub/2-logsdiag/main_hub-logsdiag.tf"
}

#--------------------------------------------------------------
#   Logs & Diagnostics Resource Group
#--------------------------------------------------------------
#   / Resource Group
resource azurerm_resource_group logdiag_rg {
  name     = lower("rg-${module.main_loc.code}-${var.subs_nickname}-hub-logsdiag")
  location = module.main_loc.location

  tags = local.base_tags
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
  lifecycle { ignore_changes = [tags["BuiltOn"]] }
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
  lifecycle { ignore_changes = [tags["BuiltOn"]] }
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
  lifecycle { ignore_changes = [tags["BuiltOn"]] }
}

#--------------------------------------------------------------
#   Logs & Diagnostics / Log Analytics Workspace
#--------------------------------------------------------------
#   / Log Analytics Workspace random Suffix
resource random_id log_analytics_workspace_name_suffix {
  byte_length = 1
}
#   / Log Analytics Workspace
resource azurerm_log_analytics_workspace hub_laws {
  name                = lower("logws-cac-${var.subs_nickname}-hub-${random_id.log_analytics_workspace_name_suffix.dec}")
  resource_group_name = azurerm_resource_group.logdiag_rg.name
  location            = "canadacentral"   # This service is not available in Canada East
  sku                 = "Free"            # Default is "PerGB2018"
  retention_in_days   = var.retention_days

  tags = local.base_tags
  lifecycle { ignore_changes = [tags["BuiltOn"]] }
}
#   / Containers Insights Solution
resource azurerm_log_analytics_solution contins_las {
  solution_name         = "ContainerInsights"
  location              = azurerm_log_analytics_workspace.hub_laws.location
  resource_group_name   = azurerm_resource_group.logdiag_rg.name
  workspace_resource_id = azurerm_log_analytics_workspace.hub_laws.id
  workspace_name        = azurerm_log_analytics_workspace.hub_laws.name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/ContainerInsights"
  }
}
#   / VMs Insights Solution
resource azurerm_log_analytics_solution vm_las {
  solution_name         = "VMInsights"
  location              = azurerm_log_analytics_workspace.hub_laws.location
  resource_group_name   = azurerm_resource_group.logdiag_rg.name
  workspace_resource_id = azurerm_log_analytics_workspace.hub_laws.id
  workspace_name        = azurerm_log_analytics_workspace.hub_laws.name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/VMInsights"
  }
}