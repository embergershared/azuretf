#--------------------------------------------------------------
#   Diag Settings for AKS Clusters in specified Resource Group
#--------------------------------------------------------------
#   / Gathering instances
data azurerm_resources aksclusters_resources {
  resource_group_name = var.rg_name
  type                = "Microsoft.ContainerService/managedClusters"
}

#   / Output the Nodes Resource Group for others Diag Settings
data azurerm_kubernetes_cluster aks_cluster {
  name                = data.azurerm_resources.aksclusters_resources.resources[0].name
  resource_group_name = var.rg_name
}

#   / Applying AKS Diagnostic Setting
resource azurerm_monitor_diagnostic_setting aks_diag {
  count                       = length(data.azurerm_resources.aksclusters_resources.resources)

  name                        = "${replace(lower(data.azurerm_resources.aksclusters_resources.resources[count.index].name), "-", "")}-diagsetting"
  target_resource_id          = data.azurerm_resources.aksclusters_resources.resources[count.index].id
  storage_account_id          = var.stacct_id
  log_analytics_workspace_id  = var.laws_id

  log {
    category    = "cluster-autoscaler"
    enabled     = true
    retention_policy {
      enabled   = true
      days      = var.retention_days
    }
  }
  log {
    category    = "kube-scheduler"
    enabled     = true
    retention_policy {
      enabled   = true
      days      = var.retention_days
    }
  }
  log {
    category    = "kube-audit"
    enabled     = true
    retention_policy {
      enabled   = true
      days      = var.retention_days
    }
  }
  log {
    category    = "kube-controller-manager"
    enabled     = true
    retention_policy {
      enabled   = true
      days      = var.retention_days
    }
  }
  log {
    category    = "kube-apiserver"
    enabled     = true
    retention_policy {
      enabled   = true
      days      = var.retention_days
    }
  }
  log {
    category    = "kube-audit-admin"
    enabled     = true
    retention_policy {
      enabled   = true
      days      = var.retention_days
    }
  }
  log {
    category    = "guard"
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