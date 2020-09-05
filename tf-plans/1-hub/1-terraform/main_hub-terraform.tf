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

# Notes         : To get Terrafom in Trace/Debug mode, do: $env:TF_LOG=TRACE

#--------------------------------------------------------------
#   Provider, locals
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
  version         = "~> 2.25.0"
  features {}
    
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
  tf_plan   = "/tf-plans/1-hub/1-terraform"

  base_tags = "${map(
    "BuiltBy", "Terraform",
    "TfPlan", "${local.tf_plan}/main_hub-terraform.tf",
    "TfValues", "${local.tf_values}/",
    "TfState", "${local.tf_state}",
    "BuiltOn","${local.nowUTC}",
    "InitiatedBy", "User",
  )}"

  # Location short for Main location
  shortl_main_location  = lookup({
      canadacentral   = "cac", 
      canadaeast      = "cae",
      eastus          = "use" },
    lower(var.main_location), "")
}

#--------------------------------------------------------------
#   Terraform States Resource Group
#--------------------------------------------------------------
#   / Resource Group
resource azurerm_resource_group tfstates_rg {
  name     = lower("rg-${local.shortl_main_location}-${var.subs_nickname}-hub-terraform")
  location = var.main_location

  tags = merge(local.base_tags, "${map(
    "RefreshedOn", "${local.nowUTC}",
  )}")
  lifecycle { ignore_changes = [tags["BuiltOn"]] }
}

#--------------------------------------------------------------
#   Terraform States Storage Account
#--------------------------------------------------------------
#   / Backend data Storage with Terraform States
resource azurerm_storage_account tfstate_storacct {
  name                        = replace(lower("st${local.shortl_main_location}${var.subs_nickname}tfstates"), "-", "")
  location                    = var.main_location
  resource_group_name         = azurerm_resource_group.tfstates_rg.name
  account_kind                = "StorageV2"
  account_tier                = "Standard"
  account_replication_type    = "LRS"
  
  tags = local.base_tags
  lifecycle { ignore_changes = [ tags ] }
}
#   / Terraform States container in Main Location
resource azurerm_storage_container tfstatecontainer {
  name                  = lower("terraform-states")
  storage_account_name  = azurerm_storage_account.tfstate_storacct.name
  container_access_type = "private"
}