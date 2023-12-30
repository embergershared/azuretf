# Description   : This Terraform plan is used to:
#                 - Setup the Diagnostics settings on SQL Databases
#
# Folder/File   : /tf-plans/2-data/2-diag/main_data-diag.tf
# Terraform     : 0.13.+
# Providers     : azurerm 2.+
# Plugins       : none
# Modules       : none
#
# Created on    : 2020-07-15
# Created by    : Emmanuel
# Last Modified : 2020-09-11
# Last Modif by : Emmanuel
# Modif desc.   : Factored common plans' blocks: terraform, provider azurerm, locals


#--------------------------------------------------------------
#   Plan's Locals
#--------------------------------------------------------------
module main_shortloc {
  source    = "../../../../../modules/shortloc"
  location  = var.main_location
}
locals {
  # Plan Tag value
  tf_plan   = "/tf-plans/2-data/2-diag/main_data-diag.tf"

  # Location short suffixes for Data Services
  shortl_data_location  = module.data_shortloc.code
}
module data_shortloc {
  source    = "../../../../../modules/shortloc"
  location  = var.data_location
}

#--------------------------------------------------------------
#   Data collection of required resources
#--------------------------------------------------------------
#   / Diagnostic Storage account
data azurerm_storage_account logsdiag_storacct {
  name                    = replace(lower("st${local.shortl_data_location}${var.subs_nickname}logsdiag"), "-", "")
  resource_group_name     = lower("rg-${local.shortl_main_location}-${var.subs_nickname}-hub-logsdiag")
}
#   / Log Analytics Workspace
data azurerm_resources hub_laws {
  resource_group_name = lower("rg-${local.shortl_main_location}-${var.subs_nickname}-hub-logsdiag")
  type                = "microsoft.operationalinsights/workspaces"
}
#   / SQL Resource Group
data azurerm_resource_group sql_rg {
  name        = lower("rg-${local.shortl_data_location}-${var.subs_nickname}-data-${var.data_env}")
}

#--------------------------------------------------------------
#   Azure Databases Diagnostics Settings
#--------------------------------------------------------------
#   / Launch module
module sqldbs_diag {
  source              = "../../../../../modules/diagsettings/sqldbs"

  # SQL Server DBs Diag Setting instance specific
  rg_name             = data.azurerm_resource_group.sql_rg.name
  stacct_id           = data.azurerm_storage_account.logsdiag_storacct.id
  laws_id             = data.azurerm_resources.hub_laws.resources[0].id
  retention_days      = var.retention_days
}
#*/