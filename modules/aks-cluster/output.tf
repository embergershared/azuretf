output shortl_cluster_location  { value = local.shortl_cluster_location }
output aks_service_principals   { value = local.aks_principals }
output aks_cluster_id           { value = azurerm_kubernetes_cluster.aks_cluster.id }

output host                     { value = azurerm_kubernetes_cluster.aks_cluster.kube_config[0].host }
output client_certificate       { value = base64decode(azurerm_kubernetes_cluster.aks_cluster.kube_config[0].client_certificate) }
output client_key               { value = base64decode(azurerm_kubernetes_cluster.aks_cluster.kube_config[0].client_key) }
output cluster_ca_certificate   { value = base64decode(azurerm_kubernetes_cluster.aks_cluster.kube_config[0].cluster_ca_certificate) }

output depended_on              { value = null_resource.aks_module_completion.id }