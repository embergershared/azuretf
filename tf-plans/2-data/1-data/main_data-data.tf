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
# Last Modified : 2020-09-23
# Last Modif by : Emmanuel
# Modif desc.   : Added sql_deploy: true | false


#--------------------------------------------------------------
#   Plan's Locals
#--------------------------------------------------------------
module main_shortloc {
  source    = "../../../../modules/shortloc"
  location  = var.main_location
}
locals {
  # Plan Tag value
  tf_plan   = "/tf-plans/2-data/1-data/main_data-data.tf"

  # Location short suffix for Data Services
  shortl_data_location  = module.data_shortloc.code
}
module data_shortloc {
  source    = "../../../../modules/shortloc"
  location  = var.data_location
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
  create_az_sp      = var.can_create_azure_servprincipals && var.sql_deploy

  tenant_id         = var.tenant_id
  subscription_id   = var.subscription_id
  tf_app_id         = var.tf_app_id
  tf_app_secret     = var.tf_app_secret

  calling_folder    = local.tf_plan
  subs_nickname     = var.subs_nickname
  subs_adm_short    = var.subs_adm_short
  sp_naming         = "data-${var.data_env}-sqlsvr"
  rotate_sp_secret  = var.sql_rotate_secret
  kv_id             = data.azurerm_key_vault.sharedsvc_kv.id
  base_tags         = local.base_tags
}

#--------------------------------------------------------------
#   Azure SQL Server
#--------------------------------------------------------------
#   / Resource Group
resource azurerm_resource_group data_rg {
  name        = lower("rg-${local.shortl_data_location}-${var.subs_nickname}-data-${var.data_env}")
  location    = var.data_location

  tags = local.base_tags
  lifecycle { ignore_changes = [tags["BuiltOn"]] }
}
#   / Azure SQL Server (using newsest provider (https://github.com/terraform-providers/terraform-provider-azurerm/issues/6502))
resource azurerm_mssql_server sqlsvr_mssql {
  count                         = var.sql_deploy ? 1 : 0

  name                          = lower("sql-${local.shortl_data_location}-${var.subs_nickname}-${var.data_env}")
  resource_group_name           = azurerm_resource_group.data_rg.name
  location                      = azurerm_resource_group.data_rg.location
  version                       = "12.0"
  public_network_access_enabled = true

  administrator_login           = var.can_create_azure_servprincipals ? module.sqlsvr_sp.sp_id : var.sql_sp_appid
  administrator_login_password  = var.can_create_azure_servprincipals ? module.sqlsvr_sp.sp_secret : var.sql_sp_appsecret

  extended_auditing_policy {
    storage_endpoint                        = data.azurerm_storage_account.stdiag.primary_blob_endpoint
    storage_account_access_key              = data.azurerm_storage_account.stdiag.primary_access_key
    storage_account_access_key_is_secondary = true
    retention_in_days                       = var.retention_days
  }

  tags = local.base_tags
  lifecycle { ignore_changes = [tags["BuiltOn"]] }
}
# #   / Azure SQL Server Extended Auditing Policy - Bugged
# resource azurerm_mssql_server_extended_auditing_policy sqlsvr_extauditpol {
#   count                                   = var.sql_deploy ? 1 : 0

#   server_id                               = azurerm_mssql_server.sqlsvr_mssql[0].id
#   storage_endpoint                        = data.azurerm_storage_account.stdiag.primary_blob_endpoint
#   storage_account_access_key              = data.azurerm_storage_account.stdiag.primary_access_key
#   storage_account_access_key_is_secondary = true
#   retention_in_days                       = var.retention_days
# }
#   / Azure SQL Server Security Alert Policy
resource azurerm_mssql_server_security_alert_policy sqlsvr_secur_alert  {
  count                 = var.sql_deploy && var.sql_enable_security ? 1 : 0

  resource_group_name   = azurerm_mssql_server.sqlsvr_mssql[0].resource_group_name
  server_name           = azurerm_mssql_server.sqlsvr_mssql[0].name
  state                 = "Enabled"
  retention_days        = var.retention_days
  email_account_admins  = false
}
#   / Container for Vulnerability assessment logs
resource azurerm_storage_container sqlsvr_vuln_cont {
  count                 = var.sql_deploy && var.sql_enable_security ? 1 : 0

  name                  = lower("${azurerm_mssql_server.sqlsvr_mssql[0].name}-vulnerability-alerts")
  storage_account_name  = data.azurerm_storage_account.stdiag.name
  container_access_type = "private"
}
#   / Azure SQL Server Vulnerability Assessment
resource azurerm_mssql_server_vulnerability_assessment sqlsvr_vuln_alert {
  count                 = var.sql_deploy && var.sql_enable_security ? 1 : 0

  server_security_alert_policy_id = azurerm_mssql_server_security_alert_policy.sqlsvr_secur_alert[0].id
  storage_container_path          = "${data.azurerm_storage_account.stdiag.primary_blob_endpoint}${azurerm_storage_container.sqlsvr_vuln_cont[0].name}/"
}

#--------------------------------------------------------------
#   Azure SQL Databases
#--------------------------------------------------------------
#   / Azure SQL Databases
resource azurerm_sql_database sql_dbs {
  for_each            = var.sql_deploy ? var.sql_dbs : []

  name                = lower("sqldb-${var.data_env}-${each.value}")
  resource_group_name = azurerm_mssql_server.sqlsvr_mssql[0].resource_group_name
  location            = azurerm_mssql_server.sqlsvr_mssql[0].location
  server_name         = azurerm_mssql_server.sqlsvr_mssql[0].name
  edition             = "Basic"

  tags = local.base_tags
  lifecycle { ignore_changes = [tags["BuiltOn"]] }
}

#--------------------------------------------------------------
#   Azure Storage Account with File Shares for AKS
#--------------------------------------------------------------
#   / Storage account
resource azurerm_storage_account data_azfiles_st {
  name                        = replace(lower("st${local.shortl_data_location}${var.subs_nickname}data${var.data_env}"), "-", "")
  location                    = azurerm_resource_group.data_rg.location
  resource_group_name         = azurerm_resource_group.data_rg.name
  account_kind                = "StorageV2"
  account_tier                = "Standard"
  account_replication_type    = "LRS"
  
  tags = local.base_tags
  lifecycle { ignore_changes = [tags["BuiltOn"]] }
}
#   / File Shares for AKS workloads as Azure Volumes
resource azurerm_storage_share aks_azfile {
  for_each              = var.aks_st_file_shares

  name                  = "${each.value}-azvolume"
  storage_account_name  = azurerm_storage_account.data_azfiles_st.name
  quota                 = 1  #in GiB
}

#--------------------------------------------------------------
#   Key Vault storage of access info
#--------------------------------------------------------------
#   / Storage Account K8S secret for AKS clusters' use
resource azurerm_key_vault_secret azfs_secret {
  name            = "${var.subs_nickname}-${local.shortl_main_location}-data-${var.data_env}-azvolume-k8ssecret"
  key_vault_id    = data.azurerm_key_vault.sharedsvc_kv.id
  not_before_date = local.nowUTCFormatted

  value           = jsonencode({
                      "azurestorageaccountname" = azurerm_storage_account.data_azfiles_st.name,
                      "azurestorageaccountkey"  = azurerm_storage_account.data_azfiles_st.primary_access_key})

  tags = merge(local.base_tags, "${map(
    "file-encoding", "utf-8",
  )}")
  lifecycle { ignore_changes  = [ tags["BuiltOn"], ] }
}
#*/