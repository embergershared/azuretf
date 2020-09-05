#--------------------------------------------------------------
#   Diag Settings for all VNet Gateways in a Resource Group
#--------------------------------------------------------------
#   / Gathering instances
data azurerm_resources vgws_resources {
  resource_group_name = var.rg_name
  type                = "Microsoft.Network/virtualNetworkGateways"
}
#   / Applying VNet Gateway Diagnostic Setting
resource azurerm_monitor_diagnostic_setting vgws_diag {
  count                       = length(data.azurerm_resources.vgws_resources.resources)

  name                        = "${replace(lower(data.azurerm_resources.vgws_resources.resources[count.index].name), "-", "")}-diagsetting"
  target_resource_id          = data.azurerm_resources.vgws_resources.resources[count.index].id
  storage_account_id          = var.stacct_id
  log_analytics_workspace_id  = var.laws_id

  log {
    category    = "GatewayDiagnosticLog"
    enabled     = true

    retention_policy {
      enabled   = true
      days      = var.retention_days
    }
  }    
  log {
    category    = "TunnelDiagnosticLog"
    enabled     = true

    retention_policy {
      enabled   = true
      days      = var.retention_days
    }
  }
  log {
    category    = "RouteDiagnosticLog"
    enabled     = true

    retention_policy {
      enabled   = true
      days      = var.retention_days
    }
  }
  log {
    category    = "IKEDiagnosticLog"
    enabled     = true

    retention_policy {
      enabled   = true
      days      = var.retention_days
    }
  }
  log {
    category    = "P2SDiagnosticLog"
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