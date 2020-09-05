# Description   : This Terraform plan is used to:
#                 - Create a SQL Server for the Tier
#                 - Create the attached databases for the microservices
#                 - Allow connectivity between SQL and AKS Pods
#                 - Activate the Diagnostic settings required
#
# Folder/File   : /tf-plans/2-data/1-data/main_data-data.tf
# Terraform     : 0.13.+
# Providers     : azurerm 2.+
# Plugins       : none
# Modules       : none
#
# Created on    : 2020-04-11
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
  tf_plan   = "/tf-plans/2-data/1-data"

  base_tags = "${map(
    "BuiltBy", "Terraform",
    "TfPlan", "${local.tf_plan}/main_data-data.tf",
    "TfValues", "${local.tf_values}/",
    "TfState", "${local.tf_state}",
    "BuiltOn","${local.nowUTC}",
    "InitiatedBy", "EB",
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
data azurerm_storage_account stdiag {
  name                  = replace(lower("st${local.shortl_main_location}${var.subs_nickname}logsdiag"), "-", "")
  resource_group_name   = lower("rg-${local.shortl_main_location}-${var.subs_nickname}-hub-logsdiag")
}
#   / Shared Services Key Vault
data azurerm_key_vault sharedsvc_kv {
  name                  = lower("kv-${local.shortl_main_location}-${var.subs_nickname}-${var.sharedsvc_kv_suffix}")
  resource_group_name   = lower("rg-${local.shortl_main_location}-${var.subs_nickname}-${var.sharedsvc_rg_name}")
}


#--------------------------------------------------------------
#   SQL Server Service Principal
#--------------------------------------------------------------
module sqlsvr_sp {
  source            = "../../../../modules/azsp"
  can_create_azure_servprincipals      = var.can_create_azure_servprincipals

  tenant_id         = var.tenant_id
  subscription_id   = var.subscription_id
  tf_app_id         = var.tf_app_id
  tf_app_secret     = var.tf_app_secret

  calling_folder    = local.tf_plan
  sp_naming         = "${var.subs_nickname}-gopher194-data-${var.data_env}-sqlsvr"
  rotate_sp_secret  = var.rotate_sql_secret
  kv_id             = data.azurerm_key_vault.sharedsvc_kv.id
  base_tags         = local.base_tags
}


#--------------------------------------------------------------
#   Azure SQL Server & Databases
#--------------------------------------------------------------
#   / Resource Group
resource azurerm_resource_group sql_rg {
  name        = lower("rg-${local.shortl_data_location}-${var.subs_nickname}-data-${var.data_env}")
  location    = var.data_location

  tags = merge(local.base_tags, "${map(
    "RefreshedOn", "${local.nowUTC}",
  )}")
  lifecycle { ignore_changes = [tags["BuiltOn"]] }
}
#   / Azure SQL Server (using newsest provdier (https://github.com-providers-provider-azurerm/issues/6502))
resource azurerm_mssql_server sqlsvr_mssql {
  name                           = lower("sql-${local.shortl_data_location}-${var.subs_nickname}-${var.data_env}")
  resource_group_name            = azurerm_resource_group.sql_rg.name
  location                       = azurerm_resource_group.sql_rg.location
  version                        = "12.0"
  administrator_login            = var.can_create_azure_servprincipals ? module.sqlsvr_sp.sp_id : var.sql_sp_appid
  administrator_login_password   = var.can_create_azure_servprincipals ? module.sqlsvr_sp.sp_secret : var.sql_sp_appsecret
  public_network_access_enabled  = true

  extended_auditing_policy {
    storage_endpoint                        = data.azurerm_storage_account.stdiag.primary_blob_endpoint
    storage_account_access_key              = data.azurerm_storage_account.stdiag.primary_access_key
    storage_account_access_key_is_secondary = true
    retention_in_days                       = var.retention_days
  }

  tags = merge(local.base_tags, "${map(
    "RefreshedOn", "${local.nowUTC}",
  )}")
  lifecycle { ignore_changes = [tags["BuiltOn"]] }
}
#   / Azure SQL Server Security Alert Policy
resource azurerm_mssql_server_security_alert_policy sqlsvr_secur_alert  { 
  resource_group_name   = azurerm_mssql_server.sqlsvr_mssql.resource_group_name
  server_name           = azurerm_mssql_server.sqlsvr_mssql.name
  state                 = "Enabled"
  retention_days        = var.retention_days
  email_account_admins  = false
}
#   / Container for Vulnerability assessment logs
resource azurerm_storage_container sqlsvr_vuln_cont {
  name                  = lower("${azurerm_mssql_server.sqlsvr_mssql.name}-vulnerability-alerts")
  storage_account_name  = data.azurerm_storage_account.stdiag.name
  container_access_type = "private"
}
#   / Azure SQL Server Vulnerability Assessment
resource azurerm_mssql_server_vulnerability_assessment sqlsvr_vuln_alert {
  server_security_alert_policy_id = azurerm_mssql_server_security_alert_policy.sqlsvr_secur_alert.id
  storage_container_path          = "${data.azurerm_storage_account.stdiag.primary_blob_endpoint}${azurerm_storage_container.sqlsvr_vuln_cont.name}/"
}

#--------------------------------------------------------------
#   Azure Databases
#--------------------------------------------------------------
#   / Azure SQL Databases
resource azurerm_sql_database sql_dbs {
  for_each            = var.sql_dbs

  name                = lower("sqldb-${var.data_env}-${each.value}")
  resource_group_name = azurerm_mssql_server.sqlsvr_mssql.resource_group_name
  location            = azurerm_mssql_server.sqlsvr_mssql.location
  server_name         = azurerm_mssql_server.sqlsvr_mssql.name
  edition             = "Basic"

  tags = merge(local.base_tags, "${map(
    "RefreshedOn", "${local.nowUTC}",
  )}")
  lifecycle { ignore_changes = [tags["BuiltOn"]] }
}


#--------------------------------------------------------------
#   Azure File Shares for AKS
#--------------------------------------------------------------
#        / Storage account
resource azurerm_storage_account data_azfiles_st {
  name                        = replace(lower("st${local.shortl_data_location}${var.subs_nickname}data${var.data_env}"), "-", "")
  location                    = azurerm_resource_group.sql_rg.location
  resource_group_name         = azurerm_resource_group.sql_rg.name
  account_kind                = "StorageV2"
  account_tier                = "Standard"
  account_replication_type    = "LRS"
  
  tags = merge(local.base_tags, "${map(
    "RefreshedOn", "${local.nowUTC}",
  )}")
  lifecycle { ignore_changes = [tags["BuiltOn"]] }
}

#        / Storing keys in Key Vault
resource azurerm_key_vault_secret data_azfiles_name {
  name         = lower("st-${local.shortl_data_location}-${var.subs_nickname}-data-${var.data_env}-name")
  value        = azurerm_storage_account.data_azfiles_st.name
  key_vault_id = data.azurerm_key_vault.sharedsvc_kv.id

  tags = merge(local.base_tags, "${map(
    "file-encoding", "utf-8",
  )}")
  lifecycle { ignore_changes  = [ tags, not_before_date ] }
}
resource azurerm_key_vault_secret data_azfiles_secret {
  name         = lower("st-${local.shortl_data_location}-${var.subs_nickname}-data-${var.data_env}-secret")
  value        = azurerm_storage_account.data_azfiles_st.primary_access_key
  key_vault_id = data.azurerm_key_vault.sharedsvc_kv.id

  tags = merge(local.base_tags, "${map(
    "file-encoding", "utf-8",
  )}")
  lifecycle { ignore_changes  = [ tags, not_before_date ] }
}
#*/