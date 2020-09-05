#--------------------------------------------------------------
#   Diag Settings for all VNets in a Resource Group
#--------------------------------------------------------------
data azurerm_resources vnets_resources {
  resource_group_name = var.rg_name
  type                = "Microsoft.Network/virtualNetworks"
}
#   ===  VNet Diagnostic Setting
resource azurerm_monitor_diagnostic_setting vnet_diag {
  count                       = length(data.azurerm_resources.vnets_resources.resources)

  name                        = "${replace(lower(data.azurerm_resources.vnets_resources.resources[count.index].name), "-", "")}-diagsetting"
  target_resource_id          = data.azurerm_resources.vnets_resources.resources[count.index].id
  storage_account_id          = var.stacct_id
  log_analytics_workspace_id  = var.laws_id

  log {
    category = "VMProtectionAlerts" # Azure Harcoded name
    enabled  = true
    retention_policy {
      days      = var.retention_days
      enabled = true
    }
  }
  metric {
    category = "AllMetrics"         # Azure Harcoded name
    enabled  = true
    retention_policy {
      days      = var.retention_days
      enabled = true
    }
  }
}