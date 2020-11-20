# Description   : This Terraform resource is used to:
#                 - Set the Diagnostics settings on all the Hub Resources
#                   which are in the following Resources Groups:
#                   - Shared Services RG
#                   - Networking RG
#                   - Jumpboxes RG
#
# Folder/File   : /tf-plans/1-hub/7-diag/main_hub-diag.tf
# Terraform     : 0.12.+
# Providers     : azurerm 2.+
# Plugins       : none
# Modules       : none
#
# Created on    : 2020-07-11
# Created by    : Emmanuel
# Last Modified : 2020-09-11
# Last Modif by : Emmanuel
# Modif desc.   : Factored common plans' blocks: terraform, provider azurerm, locals


#--------------------------------------------------------------
#   Plan's Locals
#--------------------------------------------------------------
module main_loc {
  source    = "../../../../modules/shortloc"
  location  = var.main_location
}
module secondary_loc {
  source    = "../../../../modules/shortloc"
  location  = var.secondary_location
}
locals {
  # Plan Tag value
  tf_plan   = "/tf-plans/1-hub/7-diag/main_hub-diag.tf"
}

#--------------------------------------------------------------
#   Data collection of required resources
#--------------------------------------------------------------
#   / Main location Diagnostic Storage account
data azurerm_storage_account mainloc_logdiag_stacct {
  name                    = replace(lower("st${module.main_loc.code}${var.subs_nickname}logsdiag"), "-", "")
  resource_group_name     = lower("rg-${module.main_loc.code}-${var.subs_nickname}-hub-logsdiag")
}
#   / Secondary location Diagnostic Storage account
data azurerm_storage_account secondloc_logdiag_stacct {
  name                    = replace(lower("st${module.secondary_loc.code}${var.subs_nickname}logsdiag"), "-", "")
  resource_group_name     = lower("rg-${module.main_loc.code}-${var.subs_nickname}-hub-logsdiag")
}
#   / Log Analytics Workspace
data azurerm_resources hub_laws {
  resource_group_name = lower("rg-${module.main_loc.code}-${var.subs_nickname}-hub-logsdiag")
  type                = "microsoft.operationalinsights/workspaces"
}

#--------------------------------------------------------------
#   Diagnostics for Hub Shared Services
#--------------------------------------------------------------
module sharesvc_diag {
  source              = "../../../../modules/diagsettings/hubsharedsvc"

  # Shared Services Diag Setting instance specific
  sharedsvc_rg_name   = lower("rg-${module.main_loc.code}-${var.subs_nickname}-${var.sharedsvc_rg_name}")
  mainloc_stacct      = data.azurerm_storage_account.mainloc_logdiag_stacct
  secondloc_stacct    = data.azurerm_storage_account.secondloc_logdiag_stacct
  laws_id             = data.azurerm_resources.hub_laws.resources[0].id
  retention_days      = var.retention_days
}

#--------------------------------------------------------------
#   Diagnostics for Hub Networking
#--------------------------------------------------------------
module networking_diag {
  source              = "../../../../modules/diagsettings/hubnetworking"

  # Networking Diag Setting instance specific
  networking_rg_name      = lower("rg-${module.main_loc.code}-${var.subs_nickname}-${var.hub_vnet_base_name}")
  hub_vnet_deploy_azfw    = var.hub_vnet_deploy_azfw
  hub_vnet_deploy_vnetgw  = var.hub_vnet_deploy_vnetgw
  mainloc_stacct          = data.azurerm_storage_account.mainloc_logdiag_stacct
  secondloc_stacct        = data.azurerm_storage_account.secondloc_logdiag_stacct
  laws_id                 = data.azurerm_resources.hub_laws.resources[0].id
  retention_days          = var.retention_days
}

#--------------------------------------------------------------
#   Diagnostics for Hub Jumpboxes
#--------------------------------------------------------------
module jumpboxes_diag {
  source              = "../../../../modules/diagsettings/hubjumpboxes"

  # Jumpboxes Diag Setting instance specific
  jumpboxes_rg_name       = lower("rg-${module.main_loc.code}-${var.subs_nickname}-${var.hub_vms_base_name}")
  mainloc_stacct          = data.azurerm_storage_account.mainloc_logdiag_stacct
  secondloc_stacct        = data.azurerm_storage_account.secondloc_logdiag_stacct
  laws_id                 = data.azurerm_resources.hub_laws.resources[0].id
  retention_days          = var.retention_days
}
#*/