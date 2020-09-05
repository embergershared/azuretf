output aks_managed_rg_name {
  value = data.azurerm_kubernetes_cluster.aks_cluster.node_resource_group
}