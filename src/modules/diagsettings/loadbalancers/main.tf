#   ===  Load Balancer Diagnostic Setting
data azurerm_resources loadbalancers_resources {
  resource_group_name = var.rg_name
  type                = "Microsoft.Network/loadBalancers"
}
resource azurerm_monitor_diagnostic_setting loadbalancers_diag {
  count                       = length(data.azurerm_resources.loadbalancers_resources.resources)

  name                        = "LB-${count.index}-diagsetting"
  target_resource_id          = data.azurerm_resources.loadbalancers_resources.resources[count.index].id
  storage_account_id          = data.azurerm_resources.loadbalancers_resources.resources[count.index].location == var.mainloc_stacct.location ? var.mainloc_stacct.id : var.secondloc_stacct.id
  log_analytics_workspace_id  = var.laws_id

  log {
    category    = "LoadBalancerAlertEvent"
    enabled     = true

    retention_policy {
      enabled   = true
      days      = var.retention_days
    }
  }    
  log {
    category    = "LoadBalancerProbeHealthStatus"
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