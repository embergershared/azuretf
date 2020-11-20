# Description   : This Terraform Plan creates the Hub Backend resources in Azure.
#
#                 It uses a local state that can be then uploaded in the container
#                 by uncommenting the AzureRM Backend block and rerunning the TF init
#
#                 It deploys:
#                   - a 1 Terraform resource groups in main location
#                   - in this Terraform Resource Group:
#                     - 1 Storage Account in main location
#                       - with 1 container to store the tfstate files
#
# Folder/File   : /tf-plans/1-hub/1-terraform/main_hub-terraform.tf
# Variables     : tfpsn
# Terraform     : 0.13.+
# Providers     : azurerm 2.+
# Plugins       : none
# Modules       : none
#
# Created on    : 2020-07-25
# Created by    : Emmanuel
# Last Modified : 2020-09-02
# Last Modif by : Emmanuel
# Modif desc.   : Factored common plans' blocks: terraform, provider azurerm, locals

# Notes         : To get Terraform in Trace/Debug mode, do: $env:TF_LOG="TRACE" / Clear with: $env:TF_LOG=""

#--------------------------------------------------------------
#   Plan's Locals
#--------------------------------------------------------------
module main_loc {
  source    = "../../../../modules/shortloc"
  location  = var.main_location
}
locals {
  # Plan Tag value
  tf_plan   = "/tf-plans/1-hub/1-terraform/main_hub-terraform.tf"
}

#--------------------------------------------------------------
#   Terraform States Resource Group
#--------------------------------------------------------------
#   / Resource Group
resource azurerm_resource_group tfstates_rg {
  name     = lower("rg-${module.main_loc.code}-${var.subs_nickname}-hub-terraform")
  location = module.main_loc.location

  tags = local.base_tags
  lifecycle { ignore_changes = [tags["BuiltOn"]] }
}

#--------------------------------------------------------------
#   Terraform States Storage Account
#--------------------------------------------------------------
#   / Backend data Storage with Terraform States
resource azurerm_storage_account tfstate_storacct {
  name                        = replace(lower("st${module.main_loc.code}${var.subs_nickname}tfstates"), "-", "")
  location                    = module.main_loc.location
  resource_group_name         = azurerm_resource_group.tfstates_rg.name
  account_kind                = "StorageV2"
  account_tier                = "Standard"
  account_replication_type    = "LRS"
  
  tags = local.base_tags
  lifecycle { ignore_changes = [tags["BuiltOn"]] }
}
#   / Terraform States container in Main Location
resource azurerm_storage_container tfstatecontainer {
  for_each              = var.tfstates_containers

  name                  = lower(each.value)
  storage_account_name  = azurerm_storage_account.tfstate_storacct.name
  container_access_type = "private"
}