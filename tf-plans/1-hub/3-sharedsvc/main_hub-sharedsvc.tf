# Description   : This Terraform Plan creates the Hub Shared Services resources in Azure.
#
#                 It deploys:
#                   - 1 Shared Services RG with:
#                      - Key Vault (with KeyVault access policies),
#                      - ACR,
#
#               References:
#                   https://docs.microsoft.com/en-us/azure/architecture/reference-architectures/hybrid-networking/shared-services
#
# Folder/File   : /tf-plans/1-hub/2-sharedsvc/main.tf
# Terraform     : 0.12.+
# Providers     : azurerm 2.+
# Plugins       : none
# Modules       : none
#
# Created on    : 2020-07-06
# Created by    : Emmanuel
# Last Modified :
# Last Modif by :

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
  tf_plan   = "/tf-plans/1-hub/3-sharedsvc"

  base_tags = "${map(
    "BuiltBy", "Terraform",
    "TfPlan", "${local.tf_plan}/main_hub-sharedsvc.tf",
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
#   Data collection of required resources
#--------------------------------------------------------------
data azurerm_client_config current {
}

#--------------------------------------------------------------
#   ===  Hub Shared Services  ===
#--------------------------------------------------------------
#   / Resource Group
resource azurerm_resource_group sharedsvc_rg {
  name        = lower("rg-${local.shortl_main_location}-${var.subs_nickname}-${var.sharedsvc_rg_name}")
  location    = var.main_location

  tags = merge(local.base_tags, "${map(
    "RefreshedOn", "${local.nowUTC}",
  )}")
  lifecycle { ignore_changes = [tags["BuiltOn"]] }
}

#--------------------------------------------------------------
#   Hub Shared Services / Azure Key Vault
#--------------------------------------------------------------
#   / Azure Key Vault
resource azurerm_key_vault sharedsvc_kv {
  name                            = lower("kv-${local.shortl_main_location}-${var.subs_nickname}-${var.sharedsvc_kv_suffix}")
  resource_group_name             = azurerm_resource_group.sharedsvc_rg.name
  location                        = azurerm_resource_group.sharedsvc_rg.location
  tenant_id                       = data.azurerm_client_config.current.tenant_id
  sku_name                        = "standard"
  soft_delete_enabled             = true
  purge_protection_enabled        = true
  enabled_for_disk_encryption     = false
  enabled_for_template_deployment = false
  enabled_for_deployment          = false
  
  tags = local.base_tags
  lifecycle { ignore_changes = [tags,] }
}
#   / Azure Key Vault Management Plane Access
resource azurerm_role_assignment AzOwners {
  for_each             = var.kv_owners

  scope                = azurerm_key_vault.sharedsvc_kv.id
  role_definition_name = "Owner"
  principal_id         = each.value
}
#   / Azure Key Vault Data Plane Access Policies
resource azurerm_key_vault_access_policy FullAccessPolicy {
  for_each        = var.kv_fullaccess

  key_vault_id    = azurerm_key_vault.sharedsvc_kv.id
  tenant_id       = var.tenant_id
  object_id       = each.value

  key_permissions = [
    "get", "list", "update", "create", "import", "delete", "recover", "backup", "restore",
    # Cryptographic options
    "decrypt", "encrypt", "unwrapKey", "wrapKey", "verify", "sign",
    # Privileged key options
    "purge",
  ]

  secret_permissions = [
    "get", "list", "set", "delete", "recover", "backup", "restore",
    # Privileged key options
    "purge",
  ]

  certificate_permissions = [
    "get", "list", "update", "create", "import", "delete", "recover", "backup", "restore",
    # Certificates specific
    "managecontacts", "manageissuers", "getissuers", "listissuers", "setissuers", "deleteissuers",
    # Privileged key options
    "purge",
  ]
}
#        / for user: Terraform Service Principal
resource azurerm_key_vault_access_policy TerraformAccess {
  key_vault_id    = azurerm_key_vault.sharedsvc_kv.id
  tenant_id       = var.tenant_id
  object_id       = data.azurerm_client_config.current.object_id

  key_permissions = [
    "Get", "List", "Update", "Create", "Delete", "Recover", "Import", "Backup", "Restore",
    # Cryptographic options
    "Decrypt", "Encrypt", "UnwrapKey", "WrapKey", //"verify", "sign",
    // # Privileged key options
    // "purge",
  ]

  secret_permissions = [
    "Get", "List", "Set", "Delete", "Recover", "Backup", "Restore",
    // # Privileged key options
    // "purge",
  ]

  certificate_permissions = [
    "Get", "List", //"update", "create", "import", "delete", "recover", "backup", "restore",
    // # Certificates specific
    // "managecontacts", "manageissuers", "getissuers", "listissuers", "setissuers", "deleteissuers",
    // # Privileged key options
    // "purge",
  ]
}

#--------------------------------------------------------------
#   Hub Shared Services / Azure Container Registry
#--------------------------------------------------------------
#   / Azure Container Registry
resource azurerm_container_registry hub_acr {
  name                    = lower("acr${local.shortl_main_location}${var.subs_nickname}${var.sharedsvc_acr_suffix}") # 5-50 alphanumeric characters
  resource_group_name     = azurerm_resource_group.sharedsvc_rg.name
  location                = azurerm_resource_group.sharedsvc_rg.location
  sku                     = "Basic"
  admin_enabled           = false
  
  tags = local.base_tags
  lifecycle { ignore_changes = [ tags, ] }
}