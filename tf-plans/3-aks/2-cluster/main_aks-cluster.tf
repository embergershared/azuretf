# Description   : This Terraform creates an AKS Cluster
#                 It deploys:
#                   - 1 AKS Service Principal (if var.can_create_azure_servprincipals == true),
#                   - 1 AKS Resource Group,
#                   - 1 VNet / 2 subnets,
#                   - 1 AKS cluster with Service Principal.
#

# Folder/File   : /tf-plans/3-aks/2-cluster/main_aks-cluster.tf
# Terraform     : 0.13.+
# Providers     : azurerm 2.+
# Plugins       : none
# Modules       : /aks-cluster,
#
# Created on    : 2020-07-15
# Created by    : Emmanuel
# Last Modified : 2020-10-08
# Last Modif by : Emmanuel
# Modif desc.   : Split back to AKS and k8sinfra

#--------------------------------------------------------------
#   1.: Plan's Locals
#--------------------------------------------------------------
module main_shortloc {
  source    = "../../../../../modules/shortloc"
  location  = var.main_location
}
locals {
  # Plan Tag value
  tf_plan   = "/tf-plans/3-aks/2-cluster/main_aks-cluster.tf"
}


#--------------------------------------------------------------
#   2.: Data collection of required resources (KV & ACR)
#--------------------------------------------------------------
data azurerm_key_vault kv_to_use {
  name                  = lower("kv-${local.shortl_main_location}-${var.subs_nickname}-${var.sharedsvc_kv_suffix}")
  resource_group_name   = lower("rg-${local.shortl_main_location}-${var.subs_nickname}-${var.sharedsvc_rg_name}")
}
data azurerm_container_registry acr_to_use {
  name                  = lower("acr${local.shortl_main_location}${var.subs_nickname}${var.sharedsvc_acr_suffix}") # 5-50 alphanumeric characters
  resource_group_name   = lower("rg-${local.shortl_main_location}-${var.subs_nickname}-${var.sharedsvc_rg_name}")
}
#   / Log Analytics Workspace
data azurerm_resources hub_laws {
  resource_group_name = lower("rg-${local.shortl_main_location}-${var.subs_nickname}-hub-logsdiag")
  type                = "microsoft.operationalinsights/workspaces"
}

#--------------------------------------------------------------
#   3.: AKS Cluster through module
#--------------------------------------------------------------
module aks_cluster {
  source              = "../../../../../modules/aks-cluster"

  #   / Module Mandatory settings
  calling_folder            = local.tf_plan
  cluster_location          = var.cluster_location
  aks_vnet_cidr             = var.aks_vnet_cidr
  subs_nickname             = var.subs_nickname
  cluster_name              = lower(var.cluster_name)
  k8s_version               = var.k8s_version
  laws_id                   = data.azurerm_resources.hub_laws.resources[0].id
  acr_id                    = data.azurerm_container_registry.acr_to_use.id
  secrets_kv_id             = data.azurerm_key_vault.kv_to_use.id
  hub_vnet_name             = lower("vnet-${local.shortl_main_location}-${var.subs_nickname}-${var.hub_vnet_base_name}")
  hub_rg_name               = lower("rg-${local.shortl_main_location}-${var.subs_nickname}-${var.hub_vnet_base_name}")
  base_tags                 = local.base_tags
  hub_vnet_deploy_azfw      = var.hub_vnet_deploy_azfw
  hub_azfw_name             = lower("azfw-${local.shortl_main_location}-${var.subs_nickname}-${var.hub_vnet_base_name}")
  hub_vnet_deploy_vnetgw    = var.hub_vnet_deploy_vnetgw

  #   / Module Optional settings
  enable_privcluster         = var.enable_privcluster
  enable_podsecurpol         = var.enable_podsecurpol
  enable_omsagent            = var.enable_omsagent
  enable_devspaces           = var.enable_devspaces
  enable_kdash               = var.enable_kdash
  enable_azpolicy            = var.enable_azpolicy
  enable_aci                 = var.enable_aci
  linx_admin_user            = var.linx_admin_user
  win_admin_username         = var.win_admin_user
  win_admin_password         = var.win_admin_password
  default_np_name            = var.default_np_name
  default_np_vmsize          = var.default_np_vmsize
  default_np_type            = var.default_np_type
  default_np_enablenodepubip = var.default_np_enablenodepubip
  default_np_osdisksize      = var.default_np_osdisksize
  default_np_enableautoscale = var.default_np_enableautoscale
  default_np_nodecount       = var.default_np_nodecount
  default_np_maxpods         = var.default_np_maxpods
  network_plugin             = var.network_plugin
  network_policy             = var.network_policy
  outbound_type              = var.outbound_type
  load_balancer_sku          = var.load_balancer_sku
  authorized_ips             = var.authorized_ips
  dns_service_ip             = var.dns_service_ip
  service_cidr               = var.service_cidr
  docker_bridge_cidr         = var.docker_bridge_cidr
}
#**/