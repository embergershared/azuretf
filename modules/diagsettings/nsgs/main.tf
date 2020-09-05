#   ===  Network Security Groups in Resource Group Diagnostic Setting
data azurerm_resources nsgs_resources {
  resource_group_name = var.rg_name
  type                = "Microsoft.Network/networkSecurityGroups"
}
resource azurerm_monitor_diagnostic_setting nsgs_diag {
  count                       = length(data.azurerm_resources.nsgs_resources.resources)

  name                        = "${replace(lower(data.azurerm_resources.nsgs_resources.resources[count.index].name), "-", "")}-diagsetting"
  target_resource_id          = data.azurerm_resources.nsgs_resources.resources[count.index].id
  storage_account_id          = var.stacct_id
  log_analytics_workspace_id  = var.laws_id

  log {
    category = "NetworkSecurityGroupEvent"   # Azure Harcoded name
    enabled  = true
    retention_policy {
      days    = var.retention_days
      enabled = true
    }
  }
  log {
    category = "NetworkSecurityGroupRuleCounter"   # Azure Harcoded name
    enabled  = true
    retention_policy {
      days    = var.retention_days
      enabled = true
    }
  }
}