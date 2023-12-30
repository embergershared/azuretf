#--------------------------------------------------------------
#   Diag Settings for all Public IPs in a specified Resource Group
#--------------------------------------------------------------
data azurerm_resources publicips_resources {
  resource_group_name = var.rg_name
  type                = "Microsoft.Network/publicIPAddresses"
}
resource azurerm_monitor_diagnostic_setting publicips_diag {
  count                       = length(data.azurerm_resources.publicips_resources.resources)

  name                        = "${replace(lower(data.azurerm_resources.publicips_resources.resources[count.index].name), "-", "")}-diagsetting"
  target_resource_id          = data.azurerm_resources.publicips_resources.resources[count.index].id
  storage_account_id          = data.azurerm_resources.publicips_resources.resources[count.index].location == var.mainloc_stacct.location ? var.mainloc_stacct.id : var.secondloc_stacct.id
  log_analytics_workspace_id  = var.laws_id

  log {
    category    = "DDoSProtectionNotifications"
    enabled     = true

    retention_policy {
      enabled   = true
      days      = var.retention_days
    }
  }    
  log {
    category    = "DDoSMitigationFlowLogs"
    enabled     = true

    retention_policy {
      enabled   = true
      days      = var.retention_days
    }
  }
  log {
    category    = "DDoSMitigationReports"
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