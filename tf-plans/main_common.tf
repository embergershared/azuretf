# Description   : This Terraform Plan is used by all the other Plans.
#                 It defines:
#                   - The azurerm Terraform provider to use
#                   - The locals values for all plans
#
# Folder/File   : /tf-plans/main_common.tf
# Variables     : tfpsn
# Terraform     : 0.13.+
# Providers     : azurerm 2.+
# Plugins       : none
# Modules       : none
#
# Created on    : 2020-09-10
# Created by    : Emmanuel
# Last Modified : 2020-09-11
# Last Modif by : Emmanuel
# Modif desc.   : Factored common plans' blocks: terraform, provider azurerm, locals

#--------------------------------------------------------------
#   Provider, locals
#--------------------------------------------------------------
terraform {
  required_version = ">= 0.13.3"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 2.28.0"
    }
  }
}
provider azurerm {
  version         = "~> 2.28.0"
  features {}

  tenant_id       = var.tenant_id
  subscription_id = var.subscription_id
  client_id       = var.tf_app_id
  client_secret   = var.tf_app_secret
}
provider azuread {
  version = "~> 0.10.0"

  tenant_id       = var.tenant_id
  subscription_id = var.subscription_id
  client_id       = var.tf_app_id
  client_secret   = var.tf_app_secret
}

data azurerm_client_config current {}
data azuread_service_principal tf_sp {
  application_id = data.azurerm_client_config.current.client_id
}

locals {
  # Dates formatted
  UTC_to_TZ             = "-4h"
  TZ_suffix             = "EST"
  now                   = timestamp() # in UTC

  # UTC based
  nowUTC                = formatdate("YYYY-MM-DD hh:mm ZZZ", local.now) # 2020-06-16 14:44 UTC
  nowUTCFormatted       = "${formatdate("YYYY-MM-DD", local.now)}T${formatdate("hh:mm:ss", local.now)}Z" # "2029-01-01T01:01:01Z"
  in3yearsUTC           = timeadd(local.now, "26280h")
  in3yearsUTCFormatted  = "${formatdate("YYYY-MM-DD", local.in3yearsUTC)}T${formatdate("hh:mm:ss", local.in3yearsUTC)}Z" # "2029-01-01T01:01:01Z"

  # Timezone based
  TZtime                = timeadd(local.now, local.UTC_to_TZ)
  nowTZ                 = "${formatdate("YYYY-MM-DD hh:mm", local.TZtime)} ${local.TZ_suffix}" # 2020-06-16 14:44 EST
  in3yearsTZ            = timeadd(local.TZtime, "26280h")


  # Tags values
  tf_env = terraform.workspace == "default" ? " (default)" : ":${terraform.workspace}"
  base_tags = "${map(
    "BuiltBy",      "Terraform 0.13.3",
    "InitiatedBy",  "Emmanuel",
    "TfPlan",       "${local.tf_plan}",
    "TfValues",     "${local.tf_values}",
    "TfState",      "${local.tf_state}${local.tf_env}",
    "BuiltOn",      "${local.nowTZ}",
    "RefreshedOn",  "${local.nowTZ}",
    "AutomatedBy",  "${data.azuread_service_principal.tf_sp.display_name}"
  )}"

  # Location short for Main (leveraging the shortloc module)
  shortl_main_location = module.main_shortloc.code
}