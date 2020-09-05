#--------------------------------------------------------------
#   Diag Settings for all ACRs in a Resource Group
#--------------------------------------------------------------
#   / Gathering instances
data azurerm_resources acrs_resources {
  resource_group_name = var.rg_name
  type                = "Microsoft.ContainerRegistry/registries"
}
#   / Applying ACR Diagnostic Setting
resource azurerm_monitor_diagnostic_setting acrs_diag {
  count                       = length(data.azurerm_resources.acrs_resources.resources)

  name                        = "${replace(lower(data.azurerm_resources.acrs_resources.resources[count.index].name), "-", "")}-diagsetting"
  target_resource_id          = data.azurerm_resources.acrs_resources.resources[count.index].id
  storage_account_id          = var.stacct_id
  log_analytics_workspace_id  = var.laws_id

  log {
    category    = "ContainerRegistryRepositoryEvents"
    enabled     = true

    retention_policy {
      enabled   = true
      days      = var.retention_days
    }
  }
  
  log {
    category    = "ContainerRegistryLoginEvents"
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