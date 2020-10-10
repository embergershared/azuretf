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
module main_shortloc {
  source    = "../../../../modules/shortloc"
  location  = var.main_location
}
locals {
  # Plan Tag value
  tf_plan   = "/tf-plans/1-hub/7-diag/main_hub-diag.tf"
}

#--------------------------------------------------------------
#   Data collection of required resources
#--------------------------------------------------------------
data azurerm_client_config current {
}
#   / Diagnostic Storage account
data azurerm_storage_account logadiag_storacct {
  name                    = replace(lower("st${local.shortl_main_location}${var.subs_nickname}logsdiag"), "-", "")
  resource_group_name     = lower("rg-${local.shortl_main_location}-${var.subs_nickname}-hub-logsdiag")
}
#   / Log Analytics Workspace
data azurerm_resources hub_laws {
  resource_group_name = lower("rg-${local.shortl_main_location}-${var.subs_nickname}-hub-logsdiag")
  type                = "microsoft.operationalinsights/workspaces"
}

#--------------------------------------------------------------
#   Diagnostics for Hub Shared Services
#--------------------------------------------------------------
module sharesvc_diag {
  source              = "../../../../modules/diagsettings/hubsharedsvc"

  # Shared Services Diag Setting instance specific
  sharedsvc_rg_name   = lower("rg-${local.shortl_main_location}-${var.subs_nickname}-${var.sharedsvc_rg_name}")
  stacct_id           = data.azurerm_storage_account.logadiag_storacct.id
  laws_id             = data.azurerm_resources.hub_laws.resources[0].id
  retention_days      = var.retention_days
}

#--------------------------------------------------------------
#   Diagnostics for Hub Networking
#--------------------------------------------------------------
module networking_diag {
  source              = "../../../../modules/diagsettings/hubnetworking"

  # Networking Diag Setting instance specific
  networking_rg_name      = lower("rg-${local.shortl_main_location}-${var.subs_nickname}-${var.hub_vnet_base_name}")
  hub_vnet_deploy_azfw    = var.hub_vnet_deploy_azfw
  hub_vnet_deploy_vnetgw  = var.hub_vnet_deploy_vnetgw
  stacct_id               = data.azurerm_storage_account.logadiag_storacct.id
  laws_id                 = data.azurerm_resources.hub_laws.resources[0].id
  retention_days          = var.retention_days
}

#--------------------------------------------------------------
#   Diagnostics for Hub Jumpboxes
#--------------------------------------------------------------
module jumpboxes_diag {
  source              = "../../../../modules/diagsettings/hubjumpboxes"

  # Jumpboxes Diag Setting instance specific
  jumpboxes_rg_name   = lower("rg-${local.shortl_main_location}-${var.subs_nickname}-${var.hub_vms_base_name}")
  stacct_id           = data.azurerm_storage_account.logadiag_storacct.id
  laws_id             = data.azurerm_resources.hub_laws.resources[0].id
  retention_days      = var.retention_days
}