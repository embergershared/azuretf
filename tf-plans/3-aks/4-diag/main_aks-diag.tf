# Description   : This Terraform plan is used to:
#                 - Setup the Diagnostics settings on an AKS Cluster

# Folder/File   : /tf-plans/3-aks/4-diag/main_aks-diag.tf
# Terraform     : 0.12.+
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
  tf_plan   = "/tf-plans/3-aks/3-aks/4-diag/main_aks-diag.tf"

  # Location short for AKS Cluster location
  shortl_cluster_location  = module.aks_shortloc.code
}
module aks_shortloc {
  source    = "../../../../../modules/shortloc"
  location  = var.cluster_location
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
data azurerm_resources hub_laws {
  resource_group_name = lower("rg-${local.shortl_main_location}-${var.subs_nickname}-hub-logsdiag")
  type                = "microsoft.operationalinsights/workspaces"
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
  laws_id             = data.azurerm_resources.hub_laws.resources[0].id
  retention_days      = var.retention_days
}