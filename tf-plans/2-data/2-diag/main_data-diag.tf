# Description   : This Terraform plan is used to:
#                 - Setup the Diagnostics settings on SQL Databases
#
# Folder/File   : /tf-plans/2-data/diag/main_data-diag.tf
# Terraform     : 0.13.+
# Providers     : azurerm 2.+
# Plugins       : none
# Modules       : none
#
# Created on    : 2020-07-15
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
  # Dates formatted
  now = timestamp()
  nowUTC = formatdate("YYYY-MM-DD hh:mm ZZZ", local.now) # 2020-06-16 14:44 UTC
  nowFormatted = "${formatdate("YYYY-MM-DD", local.now)}T${formatdate("hh:mm:ss", local.now)}Z" # "2029-01-01T01:01:01Z"
  in3years = timeadd(local.now, "26280h")
  in3yFormatted = "${formatdate("YYYY-MM-DD", local.in3years)}T${formatdate("hh:mm:ss", local.in3years)}Z" # "2029-01-01T01:01:01Z"

  # Tags values
  tf_plan   = "/tf-plans/2-data/2-diag"

  base_tags = "${map(
    "BuiltBy", "Terraform",
    "TfPlan", "${local.tf_plan}/main_data-diag.tf",
    "TfValues", "${local.tf_values}/",
    "TfState", "${local.tf_state}",
    "BuiltOn","${local.nowUTC}",
    "InitiatedBy", "User",
  )}"

  # Location short suffixes for Data Services
  shortl_data_location  = lookup({
      canadacentral   = "cac", 
      canadaeast      = "cae",
      eastus          = "use" },
    lower(var.data_location), "")
  shortu_data_location = upper(local.shortl_data_location)
  shortt_data_location = title(local.shortl_data_location)
  shortd_data_location = local.shortl_data_location != "" ? "-${local.shortu_data_location}" : ""

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
#   / Diagnostics Storage account
data azurerm_storage_account logsdiag_storacct {
  name                    = replace(lower("st${local.shortl_data_location}${var.subs_nickname}logsdiag"), "-", "")
  resource_group_name     = lower("rg-${local.shortl_main_location}-${var.subs_nickname}-hub-logsdiag")

}
#   / Log Analytics Workspace
data azurerm_log_analytics_workspace hub_laws {
  name                = lower("log-cac-${var.subs_nickname}-${var.hub_laws_name}")
  resource_group_name = lower("rg-${local.shortl_main_location}-${var.subs_nickname}-hub-logsdiag")
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
  laws_id             = data.azurerm_log_analytics_workspace.hub_laws.id
  retention_days      = var.retention_days
}
#*/