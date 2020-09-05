# Description   : This Terraform plan is used to:
#                 - Setup the Diagnostics settings on an AKS Cluster

# Folder/File   : /tf-plans/3-aks/3-diag/main_aks-diag.tf
# Terraform     : 0.12.+
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
  tf_plan   = "/tf-plans/3-aks/3-diag/main_aks-diag.tf"

  base_tags = "${map(
    "BuiltBy", "Terraform",
    "TfPlan", "${local.tf_plan}",
    "TfValues", "${local.tf_values}/",
    "TfState", "${local.tf_state}",
    "BuiltOn","${local.nowUTC}",
    "InitiatedBy", "User",
  )}"

  # Location short suffixes for AKS cluster
  shortl_cluster_location  = lookup({
      canadacentral   = "cac", 
      canadaeast      = "cae",
      eastus          = "use" },
    lower(var.cluster_location), "")

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
data azurerm_storage_account stdiag {
  name                    = replace(lower("st${local.shortl_cluster_location}${var.subs_nickname}logsdiag"), "-", "")
  resource_group_name     = lower("rg-${local.shortl_main_location}-${var.subs_nickname}-hub-logsdiag")
}
#   / Log Analytics Workspace
data azurerm_log_analytics_workspace hub_laws {
  name                = lower("log-cac-${var.subs_nickname}-${var.hub_laws_name}")
  resource_group_name = lower("rg-${local.shortl_main_location}-${var.subs_nickname}-hub-logsdiag")
}
#   / AKS Resource Group
data azurerm_resource_group aks_rg {
  name        = lower("rg-${local.shortl_cluster_location}-${var.subs_nickname}-aks-${var.cluster_name}")
}


#--------------------------------------------------------------
#   AKS Cluster Diagnostics Settings
#--------------------------------------------------------------
module aks_fulldiag {
  source              = "../../../../../modules/diagsettings/fullakscluster"

  aks_cluster_rg_name = data.azurerm_resource_group.aks_rg.name
  stacct_id           = data.azurerm_storage_account.stdiag.id
  laws_id             = data.azurerm_log_analytics_workspace.hub_laws.id
  retention_days      = var.retention_days
}