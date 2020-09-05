# Description   : This Terraform creates an AKS Cluster
#                 It deploys:
#                   - 1 AKS Service Principal,
#                   - 1 AKS Resource Group,
#                   - 1 VNet / 2 subnets,
#                   - 1 AKS cluster with CNI, Load Balancer
#

# Folder/File   : /tf-plans/3-aks/2-cluster/main_aks-cluster.tf
# Terraform     : 0.13.+
# Providers     : azurerm 2.+
# Plugins       : none
# Modules       : /az-sp, /aks
#
# Created on    : 2020-07-15
# Created by    : Emmanuel
# Last Modified :
# Last Modif by :

#--------------------------------------------------------------
#   Terraform Initialization
#--------------------------------------------------------------
terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
  }
  required_version = ">= 0.13"
}
provider azurerm {
  version         = "~> 2.12"
  features        {}

  tenant_id       = var.tenant_id
  subscription_id = var.subscription_id
  client_id       = var.tf_app_id
  client_secret   = var.tf_app_secret
}
locals {
  # Dates formatted
  now           = timestamp()
  nowUTC        = formatdate("YYYY-MM-DD hh:mm ZZZ", local.now)                                   # 2020-06-16 14:44 UTC
  nowFormatted  = "${formatdate("YYYY-MM-DD", local.now)}T${formatdate("hh:mm:ss", local.now)}Z"  # "2029-01-01T01:01:01Z"

  # Tags values
  tf_plan   = "/tf-plans/3-aks/2-cluster"

  base_tags = "${map(
    "BuiltBy", "Terraform",
    "TfPlan", "${local.tf_plan}/main_aks-cluster.tf",
    "TfValues", "${local.tf_values}/",
    "TfState", "${local.tf_state}",
    "BuiltOn", "${local.nowUTC}",
    "InitiatedBy", "EB",
  )}"

  # Location short for Main location
  shortl_main_location  = lookup({
      canadacentral   = "cac", 
      canadaeast      = "cae",
      eastus          = "use" },
    lower(var.main_location), "")
}

#--------------------------------------------------------------
#   Data collection of required resources (KV & ACR)
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
data azurerm_log_analytics_workspace hub_laws {
  name                = lower("log-cac-${var.subs_nickname}-${var.hub_laws_name}")
  resource_group_name = lower("rg-${local.shortl_main_location}-${var.subs_nickname}-hub-logsdiag")
}

#--------------------------------------------------------------
#   AKS Service Principal
#--------------------------------------------------------------
module aks_sp {
  source            = "../../../../modules/azsp"
  can_create_azure_servprincipals      = var.can_create_azure_servprincipals

  tenant_id         = var.tenant_id
  subscription_id   = var.subscription_id
  tf_app_id         = var.tf_app_id
  tf_app_secret     = var.tf_app_secret

  calling_folder    = local.tf_plan
  sp_naming         = lower("${var.subs_nickname}-gopher194-aks-${var.cluster_name}")
  rotate_sp_secret  = var.rotate_aks_secret
  kv_id             = data.azurerm_key_vault.kv_to_use.id
  base_tags         = local.base_tags
}

#--------------------------------------------------------------
#   AKS Cluster through module
#--------------------------------------------------------------
module aks_cluster {
  source              = "../../../../modules/aks"

  #   / Module Mandatory settings
  calling_folder            = local.tf_plan
  cluster_location          = var.cluster_location
  aks_vnet_cidr             = var.aks_vnet_cidr
  ilb_vnet_cidr             = var.ilb_vnet_cidr
  subs_nickname             = var.subs_nickname
  cluster_name              = lower(var.cluster_name)
  k8s_version               = var.k8s_version
  aks_sp_id                 = var.can_create_azure_servprincipals ? module.aks_sp.sp_id : var.aks_sp_appid
  aks_sp_secret             = var.can_create_azure_servprincipals ? module.aks_sp.sp_secret : var.aks_sp_appsecret
  aks_sp_objid              = var.can_create_azure_servprincipals ? module.aks_sp.sp_objid : var.aks_sp_objid
  linx_ssh_pubkey_path      = var.ssh_pubkey_path
  laws_id                   = data.azurerm_log_analytics_workspace.hub_laws.id
  acr_id                    = data.azurerm_container_registry.acr_to_use.id
  secrets_kv_id             = data.azurerm_key_vault.kv_to_use.id
  hub_vnet_name             = lower("vnet-${local.shortl_main_location}-${var.subs_nickname}-${var.hub_vnet_base_name}")
  hub_rg_name               = lower("rg-${local.shortl_main_location}-${var.subs_nickname}-${var.hub_vnet_base_name}")
  base_tags                 = local.base_tags
  hub_vnet_deploy_azfw      = var.hub_vnet_deploy_azfw
  hub_vnet_deploy_vnetgw    = var.hub_vnet_deploy_vnetgw
  aks_cluster_admins_AADIds = var.aks_cluster_admins_AADIds

  #   / Module Optional settings
  enable_privcluster         = var.enable_privcluster
  enable_podsecurpol         = var.enable_podsecurpol
  enable_omsagent            = var.enable_omsagent
  enable_devspaces           = var.enable_devspaces
  enable_kdash               = var.enable_kdash
  enable_azpolicy            = var.enable_azpolicy
  enable_aci                 = var.enable_aci
  linx_admin_user            = var.linx_admin_user
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
}
#**/

/**
#--------------------------------------------------------------
#   AKS Specific Notes
#--------------------------------------------------------------
#   To get the Credentials:
#az aks get-credentials -g rg-cac-msdn-aks-annecy -n aks-cac-msdn-annecy --admin --overwrite-existing --file kubeconfig
#
#   To launch the K8S Dashboard:
#az aks browse -g rg-cac-msdn-aks-annecy -n aks-cac-msdn-annecy
#
#   To SSH in a node:
#   - Change permissions on Private Key as per: https://superuser.com/questions/1296024/windows-ssh-permissions-for-private-key-are-too-open
#     => Security / Advanced / Disable inheritance / ad\eb Owner
#   - Connect to VPN
#   - As Admin, add route to AKS Vnet: route add 10.60.0.0 mask 255.255.240.0 192.168.15.5 metric 10
#   - ssh -i "D:\Dropbox\2.InfraHarvard\SshKeys\aks_ssh_privatekey.pem" linxadm@10.60.0.4
**/