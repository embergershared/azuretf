#--------------------------------------------------------------
#   Diag Settings for all Application Gateways in a Resource Group
#--------------------------------------------------------------
#   / Gathering instances
data azurerm_resources agws_resources {
  resource_group_name = var.rg_name
  type                = "Microsoft.Network/applicationGateways"
}
#   / Applying VNet Gateway Diagnostic Setting
resource azurerm_monitor_diagnostic_setting agws_diag {
  count                       = length(data.azurerm_resources.agws_resources.resources)

  name                        = "${replace(lower(data.azurerm_resources.agws_resources.resources[count.index].name), "-", "")}-diagsetting"
  target_resource_id          = data.azurerm_resources.agws_resources.resources[count.index].id
  storage_account_id          = data.azurerm_resources.agws_resources.resources[count.index].location == var.mainloc_stacct.location ? var.mainloc_stacct.id : var.secondloc_stacct.id
  log_analytics_workspace_id  = var.laws_id

  log {
    category    = "ApplicationGatewayAccessLog"
    enabled     = true

    retention_policy {
      enabled   = true
      days      = var.retention_days
    }
  }
  
  log {
    category    = "ApplicationGatewayPerformanceLog"
    enabled     = true

    retention_policy {
      enabled   = true
      days      = var.retention_days
    }
  }

  log {
    category    = "ApplicationGatewayFirewallLog"
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