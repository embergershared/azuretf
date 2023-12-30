#   ===  Network Interface Cards in Resource Group
data azurerm_resources nics_resources {
  resource_group_name = var.rg_name
  type                = "Microsoft.Network/networkInterfaces"
}
resource azurerm_monitor_diagnostic_setting nics_diag {
  count                       = length(data.azurerm_resources.nics_resources.resources)

  name                        = "nic-${count.index}-diagsetting"
  target_resource_id          = data.azurerm_resources.nics_resources.resources[count.index].id
  storage_account_id          = data.azurerm_resources.nics_resources.resources[count.index].location == var.mainloc_stacct.location ? var.mainloc_stacct.id : var.secondloc_stacct.id
  log_analytics_workspace_id  = var.laws_id

  metric {
    category = "AllMetrics"                     # Azure Harcoded name
    enabled  = true
    
    retention_policy {
      days    = var.retention_days
      enabled = true
    }
  }
}