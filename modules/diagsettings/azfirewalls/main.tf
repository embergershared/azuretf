#--------------------------------------------------------------
#   Diag Settings for all Azure Firewalls in a Resource Group
#--------------------------------------------------------------
#   / Gathering instances
data azurerm_resources azfw_resources {
  resource_group_name = var.rg_name
  type                = "Microsoft.Network/azureFirewalls"
}
#   / Applying Azure Firewall Diagnostic Setting
resource azurerm_monitor_diagnostic_setting azfw_diag {
  count                       = length(data.azurerm_resources.azfw_resources.resources)

  name                        = "${replace(lower(data.azurerm_resources.azfw_resources.resources[count.index].name), "-", "")}-diagsetting"
  target_resource_id          = data.azurerm_resources.azfw_resources.resources[count.index].id
  storage_account_id          = var.stacct_id
  log_analytics_workspace_id  = var.laws_id

  log {
    category = "AzureFirewallApplicationRule"   # Azure Harcoded name
    enabled  = true
    retention_policy {
      days      = var.retention_days
      enabled   = true
    }
  }
  log {
    category = "AzureFirewallNetworkRule"       # Azure Harcoded name
    enabled  = true
    retention_policy {
      days      = var.retention_days
      enabled   = true
    }
  }
  log {
    category = "AzureFirewallDnsProxy"          # Azure Harcoded name
    enabled  = true
    retention_policy {
      days      = var.retention_days
      enabled   = true
    }
  }
  
  metric {
    category = "AllMetrics"                     # Azure Harcoded name
    enabled  = true
    retention_policy {
      days      = var.retention_days
      enabled   = true
    }
  }
}