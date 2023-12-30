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
# Modif desc.   : Rewiring to connect akv2k8s to out of sub KV

#--------------------------------------------------------------
#   Plan's Locals
#--------------------------------------------------------------
module main_loc {
  source    = "../../../../../modules/shortloc"
  location  = var.main_location
}
locals {
  # Plan Tag value
  tf_plan   = "/tf-plans/3-aks/3-k8sinfra/main_aks-k8sinfra.tf"
}
module aks_loc {
  source    = "../../../../../modules/shortloc"
  location  = var.cluster_location
}

#--------------------------------------------------------------
#   Data collection of required resources (KV & ACR)
#--------------------------------------------------------------
#   / AKS Subscription Hub Key Vault
data azurerm_key_vault aks_sub_kv {
  name                  = lower("kv-${module.main_loc.code}-${var.subs_nickname}-${var.sharedsvc_kv_suffix}")
  resource_group_name   = lower("rg-${module.main_loc.code}-${var.subs_nickname}-${var.sharedsvc_rg_name}")
}

#   / Private DNS to connect to RG:
#   / Hub networking Resource Group
data azurerm_resource_group hub_vnet_rg {
  name        = lower("rg-${module.main_loc.code}-${var.subs_nickname}-${var.hub_vnet_base_name}")
}

#   / Service Principal Tenant to access Data subscription
data azurerm_key_vault_secret data_sub_tf_tenantid {
  key_vault_id  = data.azurerm_key_vault.aks_sub_kv.id
  name          = var.data_sub_access_sp_tenantid_kvsecret
}
#   / Service Principal Id to access Data subscription
data azurerm_key_vault_secret data_sub_tf_appid {
  key_vault_id  = data.azurerm_key_vault.aks_sub_kv.id
  name          = var.data_sub_access_sp_appid_kvsecret
}
#   / Service Principal Secret to access Data subscription
data azurerm_key_vault_secret data_sub_tf_appsecret {
  key_vault_id  = data.azurerm_key_vault.aks_sub_kv.id
  name          = var.data_sub_access_sp_secret_kvsecret
}
#   / Data Subscription: Key Vault Resource Id to use
#   (SP requires "Get" access policy role in Data Sub Key Vault)
data azurerm_key_vault_secret data_sub_kv_id {
  key_vault_id  = data.azurerm_key_vault.aks_sub_kv.id
  name          = var.data_sub_kv_id_kvsecret
}
#   / Data Subscription: ACR name to use
#   (SP requires "AcrPull" role in Data Sub ACR)
data azurerm_key_vault_secret data_sub_acr_name {
  key_vault_id  = data.azurerm_key_vault.aks_sub_kv.id
  name          = var.data_sub_acr_kvsecret
}

#--------------------------------------------------------------
#   K8S Infrastrusture through module
#--------------------------------------------------------------
module aks_k8sinfra {
  source                = "../../../../../modules/aks-k8sinfra"
  dependencies          = [ ]
  base_tags             = local.base_tags

  #   / AKS Cluster
  aks_cluster_name    = lower("aks-${module.aks_loc.code}-${var.subs_nickname}-${var.cluster_name}")
  aks_cluster_rg_name = lower("rg-${module.aks_loc.code}-${var.subs_nickname}-aks-${var.cluster_name}")

  #   / K8sinfra
  piping_name         = var.piping_name
  deploy_ilb          = var.deploy_ilb
  ilb_ip_suffix       = var.ilb_ip_suffix

  #   / Private DNS Resource Group
  privdns_rg_name     = data.azurerm_resource_group.hub_vnet_rg.name

  ### / Use Data Subscription
  #   / Service Principal in the data subscription to use to connect
  data_sub_access_sp_tenantid = data.azurerm_key_vault_secret.data_sub_tf_tenantid.value
  data_sub_access_sp_appid    = data.azurerm_key_vault_secret.data_sub_tf_appid.value
  data_sub_access_sp_secret   = data.azurerm_key_vault_secret.data_sub_tf_appsecret.value
  #   / Data subscription Key Vault
  data_sub_kv_id              = data.azurerm_key_vault_secret.data_sub_kv_id.value
  #   / Data subscription ACR
  data_sub_acr_name           = data.azurerm_key_vault_secret.data_sub_acr_name.value
}
#**/