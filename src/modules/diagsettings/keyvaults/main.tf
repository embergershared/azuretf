#--------------------------------------------------------------
#   Diag Settings for all KeyVaults in a Resource Group
#--------------------------------------------------------------
#   / Gathering instances
data azurerm_resources kvs_resources {
  resource_group_name = var.rg_name
  type                = "Microsoft.KeyVault/vaults"
}
#   / Applying KeyVault Diagnostic Setting
resource azurerm_monitor_diagnostic_setting kvs_diag {
  count                       = length(data.azurerm_resources.kvs_resources.resources)

  name                        = "${replace(lower(data.azurerm_resources.kvs_resources.resources[count.index].name), "-", "")}-diagsetting"
  target_resource_id          = data.azurerm_resources.kvs_resources.resources[count.index].id
  storage_account_id          = data.azurerm_resources.kvs_resources.resources[count.index].location == var.mainloc_stacct.location ? var.mainloc_stacct.id : var.secondloc_stacct.id
  log_analytics_workspace_id  = var.laws_id

  log {
    category    = "AuditEvent"
    enabled     = true
    retention_policy {
      enabled   = true
      days      = var.retention_days
    }
  }

  metric {
    category = "AllMetrics"
    retention_policy {
      enabled   = true
      days      = var.retention_days
    }
  }
}