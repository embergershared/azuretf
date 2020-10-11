# Description   : This Terraform creates an AKS Cluster
#                 It calls the module aks-k8sinfra

# Folder/File   : /tf-plans/3-aks/3-k8sinfra/main_aks-k8sinfra.tf
# Terraform     : 0.13.+
# Providers     : azurerm 2.+
# Plugins       : none
# Modules       : /aks-k8sinfra
#
# Created on    : 2020-07-15
# Created by    : Emmanuel
# Last Modified : 2020-10-09
# Last Modif by : Emmanuel
# Modif desc.   : Rewired to connect akv2k8s to out of sub KV

#--------------------------------------------------------------
#   Plan's Locals
#--------------------------------------------------------------
module main_shortloc {
  source    = "../../../../../modules/shortloc"
  location  = var.main_location
}
locals {
  # Plan Tag value
  tf_plan   = "/tf-plans/3-aks/3-k8sinfra/main_aks-k8sinfra.tf"

  # Location short suffix for AKS Cluster
  shortl_cluster_location  = module.aks_shortloc.code
}
module aks_shortloc {
  source    = "../../../../../modules/shortloc"
  location  = var.cluster_location
}

#--------------------------------------------------------------
#   Data collection of required resources (KV & ACR)
#--------------------------------------------------------------
data azurerm_key_vault kv_to_use {
  name                  = lower("kv-${local.shortl_main_location}-${var.subs_nickname}-${var.sharedsvc_kv_suffix}")
  resource_group_name   = lower("rg-${local.shortl_main_location}-${var.subs_nickname}-${var.sharedsvc_rg_name}")
}

#--------------------------------------------------------------
#   K8S Infrastrusture through module
#--------------------------------------------------------------
module aks_k8sinfra {
  source                = "../../../../../modules/aks-k8sinfra"
  dependencies          = [ ]

  #   / AKS Cluster
  aks_cluster_name    = lower("aks-${local.shortl_cluster_location}-${var.subs_nickname}-${var.cluster_name}")
  aks_cluster_rg_name = lower("rg-${local.shortl_cluster_location}-${var.subs_nickname}-aks-${var.cluster_name}")

  #   / Key Vault
  aks_sub_kv_id                   = data.azurerm_key_vault.kv_to_use.id
  data_sub_tfsp_tenantid_kvsecret = var.data_sub_tfsp_tenantid_kvsecret   
  data_sub_tfsp_subid_kvsecret    = var.data_sub_tfsp_subid_kvsecret      
  data_sub_tfsp_appid_kvsecret    = var.data_sub_tfsp_appid_kvsecret      
  data_sub_tfsp_secret_kvsecret   = var.data_sub_tfsp_secret_kvsecret     

  #   / K8sinfra
  piping_name         = var.piping_name
  deploy_ilb          = var.deploy_ilb
  ilb_ip_suffix       = var.ilb_ip_suffix
}
#**/