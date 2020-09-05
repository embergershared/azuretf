#--------------------------------------------------------------
#   Diag Settings for Items types in an AKS Cluster
#--------------------------------------------------------------
#   / AKS Cluster Diag setting
module aks_cluster_diag {
  source              = "../aksclusters"

  # AKS Cluster Diag Setting instance specific
  rg_name             = var.aks_cluster_rg_name
  stacct_id           = var.stacct_id
  laws_id             = var.laws_id
  retention_days      = var.retention_days
}
#   / AKS VNet Diag module
module aks_vnet_diag {
  source              = "../vnets"

  # VNet Diag Setting instance specific
  rg_name             = var.aks_cluster_rg_name
  stacct_id           = var.stacct_id
  laws_id             = var.laws_id
  retention_days      = var.retention_days
}
#   / AKS Load balancers Diag module
module aks_lbs_diag {
  source              = "../loadbalancers"

  # AKS Loadbalancers Diag Setting instance specific
  rg_name             = module.aks_cluster_diag.aks_managed_rg_name
  stacct_id           = var.stacct_id
  laws_id             = var.laws_id
  retention_days      = var.retention_days
}
#   / AKS Public IPs Diag module
module aks_pips_diag {
  source              = "../publicips"

  # AKS Loadbalancer Diag Setting instance specific
  rg_name             = module.aks_cluster_diag.aks_managed_rg_name
  stacct_id           = var.stacct_id
  laws_id             = var.laws_id
  retention_days      = var.retention_days
}
#   / AKS NSGs Diag module
module aks_nsgs_diag {
  source              = "../nsgs"

  # AKS NSG Diag Setting instance specific
  rg_name             = module.aks_cluster_diag.aks_managed_rg_name
  stacct_id           = var.stacct_id
  laws_id             = var.laws_id
  retention_days      = var.retention_days
}