#--------------------------------------------------------------
#   Diag Settings for SQL Databases in specified Resource Group
#--------------------------------------------------------------
#   / Gathering instances
data azurerm_resources all_dbs {
  resource_group_name     = var.rg_name
  type                    = "Microsoft.Sql/servers/databases"
}
#   / Applying SQL Db Diagnostic Setting
resource azurerm_monitor_diagnostic_setting db_diag {
  count                       = length(data.azurerm_resources.all_dbs.resources)

  name                        = "${replace(lower(split("/", data.azurerm_resources.all_dbs.resources[count.index].name)[1]), "-", "")}-diagsetting"
  target_resource_id          = data.azurerm_resources.all_dbs.resources[count.index].id
  storage_account_id          = var.stacct_id
  log_analytics_workspace_id  = var.laws_id

  log {
    category    = "SQLInsights"
    enabled     = true

    retention_policy {
      enabled   = true
      days      = var.retention_days
    }
  }
  log {
    category    = "AutomaticTuning"
    enabled     = true

    retention_policy {
      enabled   = true
      days      = var.retention_days
    }
  }
  log {
    category    = "QueryStoreRuntimeStatistics"
    enabled     = true

    retention_policy {
      enabled   = true
      days      = var.retention_days
    }
  }
  log {
    category    = "QueryStoreWaitStatistics"
    enabled     = true

    retention_policy {
      enabled   = true
      days      = var.retention_days
    }
  }
  log {
    category    = "Errors"
    enabled     = true

    retention_policy {
      enabled   = true
      days      = var.retention_days
    }
  }
  log {
    category    = "DatabaseWaitStatistics"
    enabled     = true

    retention_policy {
      enabled   = true
      days      = var.retention_days
    }
  }
  log {
    category    = "Timeouts"
    enabled     = true

    retention_policy {
      enabled   = true
      days      = var.retention_days
    }
  }
  log {
    category    = "Blocks"
    enabled     = true

    retention_policy {
      enabled   = true
      days      = var.retention_days
    }
  }
  log {
    category    = "Deadlocks"
    enabled     = true

    retention_policy {
      enabled   = true
      days      = var.retention_days
    }
  }
  log {
    category    = "SQLSecurityAuditEvents"
    enabled     = true

    retention_policy {
      enabled   = true
      days      = var.retention_days
    }
  }
  log {
    category    = "DevOpsOperationsAudit"
    enabled     = true

    retention_policy {
      enabled   = true
      days      = var.retention_days
    }
  }

  metric {
    category    = "Basic"
    enabled     = true

    retention_policy {
      enabled   = true
      days      = var.retention_days
    }
  }
  metric {
    category    = "InstanceAndAppAdvanced"
    enabled     = true

    retention_policy {
      enabled   = true
      days      = var.retention_days
    }
  }
  metric {
    category = "WorkloadManagement"
    enabled  = true
      
    retention_policy {
      days      = var.retention_days
      enabled = true
    }
  }

  lifecycle { ignore_changes = [ target_resource_id, ] }
}