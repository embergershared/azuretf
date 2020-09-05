# Description   : This Terraform resource is used to:
#                 - Set the Diagnostics settings on all the Hub Resources
#                   which are in the following Resources Groups:
#                   - Shared Services RG
#                   - Networking RG
#                   - Jumpboxes RG
#
# Folder/File   : /tf-plans/1-hub/7-diags/main_hub-diags.tf
# Terraform     : 0.12.+
# Providers     : azurerm 2.+
# Plugins       : none
# Modules       : none
#
# Created on    : 2020-07-11
# Created by    : Emmanuel
# Last Modified : 2020-09-03
# Last Modif by : Emmanuel

#--------------------------------------------------------------
#   Terraform Initialization
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
  features        {}

  tenant_id       = var.tenant_id
  subscription_id = var.subscription_id
  client_id       = var.tf_app_id
  client_secret   = var.tf_app_secret
}
locals {
  # Tags values
  tf_plan   = "/tf-plans/1-hub/7-diags"

  # Location short for Main location
  shortl_main_location  = lookup({
      canadacentral   = "cac", 
      canadaeast      = "cae",
      eastus          = "use" },
    lower(var.main_location), "")
}

#--------------------------------------------------------------
#   Data collection of required resources
#--------------------------------------------------------------
data azurerm_client_config current {
}
data azurerm_storage_account logadiag_storacct {
  name                    = replace(lower("st${local.shortl_main_location}${var.subs_nickname}logsdiag"), "-", "")
  resource_group_name     = lower("rg-${local.shortl_main_location}-${var.subs_nickname}-hub-logsdiag")
}
data azurerm_log_analytics_workspace hub_laws {
  name                = lower("log-cac-${var.subs_nickname}-${var.hub_laws_name}")
  resource_group_name = lower("rg-${local.shortl_main_location}-${var.subs_nickname}-hub-logsdiag")
}

#--------------------------------------------------------------
#   Diagnostics for Hub Shared Services
#--------------------------------------------------------------
module sharesvc_diag {
  source              = "../../../../modules/diagsettings/hubsharedsvc"

  # Shared Services Diag Setting instance specific
  sharedsvc_rg_name   = lower("rg-${local.shortl_main_location}-${var.subs_nickname}-${var.sharedsvc_rg_name}")
  stacct_id           = data.azurerm_storage_account.logadiag_storacct.id
  laws_id             = data.azurerm_log_analytics_workspace.hub_laws.id
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
  laws_id                 = data.azurerm_log_analytics_workspace.hub_laws.id
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
  laws_id             = data.azurerm_log_analytics_workspace.hub_laws.id
  retention_days      = var.retention_days
}