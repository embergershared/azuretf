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
module main_loc {
  source    = "../../../../../modules/shortloc"
  location  = var.main_location
}
module secondary_loc {
  source    = "../../../../../modules/shortloc"
  location  = var.secondary_location
}
module aks_loc {
  source    = "../../../../../modules/shortloc"
  location  = var.cluster_location
}

locals {
  # Plan Tag value
  tf_plan   = "/tf-plans/3-aks/3-aks/4-diag/main_aks-diag.tf"
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
#   / AKS Resource Group
data azurerm_resource_group aks_rg {
  name        = lower("rg-${module.aks_loc.code}-${var.subs_nickname}-aks-${var.cluster_name}")
}

#--------------------------------------------------------------
#   AKS Cluster Diagnostics Settings
#--------------------------------------------------------------
module aks_fulldiag {
  source              = "../../../../../modules/diagsettings/fullakscluster"

  aks_cluster_rg_name = data.azurerm_resource_group.aks_rg.name
  mainloc_stacct      = data.azurerm_storage_account.mainloc_logdiag_stacct
  secondloc_stacct    = data.azurerm_storage_account.secondloc_logdiag_stacct
  laws_id             = data.azurerm_resources.hub_laws.resources[0].id
  retention_days      = var.retention_days
}