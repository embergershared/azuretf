# Description   : This Terraform creates the kubernetes foundation in an AKS Cluster
#                 It deploys:
#                   - 1 AKS Service Principal,
#                   - 1 AKS Resource Group,
#                   - 1 VNet / 2 subnets,
#                   - 1 AKS cluster with CNI, Load Balancer
#
# Folder/File   : /tf-plans/3-aks/5-k8svalidate/main_aks-k8sinfra.tf
# Terraform     : 0.13.+
# Providers     : azurerm 2.+
# Plugins       : none
# Modules       : none
#
# Created on    : 2020-06-16
# Created by    : Emmanuel
# Last Modified : 2020-09-23
# Last Modif by : Emmanuel
# Modif desc.   : Removed aad-pod-identity

# Notes:
#     Debug a Helm chart:
#     helm install --debug --dry-run aks-veyrier-secret-inj ../validate/akv2k8s-injecttestapp --namespace akv2k8s-test --set akvsResourceName=k8s-validate-veyrier-secret-inj


#--------------------------------------------------------------
#   1.: Terraform Initialization
#--------------------------------------------------------------
provider kubernetes {
  version                 = "~> 1.11"
  load_config_file        = "false"

  host                    = local.host
  #### Auth Option1: TLS Certificate
  client_certificate      = local.client_certificate
  client_key              = local.client_key
  cluster_ca_certificate  = local.cluster_ca_certificate
}
provider helm {
  # Ref: https://registry.terraform.io/providers/hashicorp/helm/latest/docs
  #      https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release
  version             = "~> 1.2.2"
  kubernetes {
    load_config_file       = "false"
    host                   = local.host
    #### Auth Option1: TLS Certificate
    client_certificate     = local.client_certificate
    client_key             = local.client_key
    cluster_ca_certificate = local.cluster_ca_certificate
  }
}
module main_loc {
  source    = "../../../../../modules/shortloc"
  location  = var.main_location
}
module aks_loc {
  source    = "../../../../../modules/shortloc"
  location  = var.cluster_location
}
locals {
  # Plan Tag value
  tf_plan   = "/tf-plans/3-aks/5-k8svalidate/main_aks-k8svalidate.tf"

  # kubeconfig access data
  host                     = data.azurerm_kubernetes_cluster.aks_cluster.kube_config[0].host
  client_certificate       = base64decode(data.azurerm_kubernetes_cluster.aks_cluster.kube_config[0].client_certificate)
  client_key               = base64decode(data.azurerm_kubernetes_cluster.aks_cluster.kube_config[0].client_key)
  cluster_ca_certificate   = base64decode(data.azurerm_kubernetes_cluster.aks_cluster.kube_config[0].cluster_ca_certificate)
}


#--------------------------------------------------------------
#   2.: Data collection of required resources (KV, ACR & AKS)
#--------------------------------------------------------------
#   / AKS
data azurerm_kubernetes_cluster aks_cluster {
  name                        = lower("aks-${module.aks_loc.code}-${var.subs_nickname}-${var.cluster_name}")
  resource_group_name         = lower("rg-${module.aks_loc.code}-${var.subs_nickname}-aks-${var.cluster_name}")
}
data azurerm_resource_group aks_nodes_rg {
  name                = data.azurerm_kubernetes_cluster.aks_cluster.node_resource_group
}

#   / AKS Subscription Key Vault
data azurerm_key_vault aks_sub_kv {
  name                  = lower("kv-${module.main_loc.code}-${var.subs_nickname}-${var.sharedsvc_kv_suffix}")
  resource_group_name   = lower("rg-${module.main_loc.code}-${var.subs_nickname}-${var.sharedsvc_rg_name}")
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
#   3.: Test akv2k8s
#--------------------------------------------------------------
locals {
  data_sub_kv_name              = split("/", data.azurerm_key_vault_secret.data_sub_kv_id.value)[8]
  data_sub_validate_secret_name = var.data_sub_validate_secret_name
}
#   / Create a test namespace in the cluster
resource kubernetes_namespace akv2k8s_test_ns {
  metadata {
    name = "akv2k8s-test"
    labels = {
      "azure-key-vault-env-injection" = "enabled"
    }
  }
}
#   / Testing Secret1 Synchronization (akv2k8s Controller)
locals {
  sync_akvs_crd_name = "${local.data_sub_validate_secret_name}-sync"
}
resource helm_release secret_sync_release {
  depends_on = [ ]

  name      = local.sync_akvs_crd_name
  chart     = "../../../../../charts/akv2k8s/use/akv2k8s-sync"
  namespace = kubernetes_namespace.akv2k8s_test_ns.metadata[0].name
  version   = "1.0.0"

  set {
    name  = "keyvaultName"
    # This is the Key Vault name:
    value = local.data_sub_kv_name
  }
  set {
    name  = "keyvaultObjectName"
    # This is the Key Vault secret name in Key Vault:
    value = local.data_sub_validate_secret_name
  }

  set {
    name  = "k8sSecretName"
    # This is the secret name in Kubernetes (and the akvs CRD object name):
    value = local.sync_akvs_crd_name
  }
  set {
    name  = "dataKey"
    # This is the key for the 1 data value of the Kubernetes secret
    value = "value"
  }
}

#     / Control result:
#       k get akvs -A
#       k -n akv2k8s-test get secret validation-secret-sync -o yaml
#       echo 'SWYgeW91IHNlZSB0aGlzIHNlY3JldCwgaXQgd29ya2VkIQ==' | base64 --decode
#       => should display the secret value text "This string is the value of the test ..."


#   / Testing Secret Injection (the Injector+Env)
#     / Deploy test injection
locals {
  inj_akvs_crd_name = "${local.data_sub_validate_secret_name}-inj"
}
resource kubernetes_secret imagepull {
  metadata {
    name      = "acr-imagepull"
    namespace  = kubernetes_namespace.akv2k8s_test_ns.metadata[0].name
  }

  data = {
    ".dockerconfigjson" = <<DOCKER
{
  "auths": {
    "${data.azurerm_key_vault_secret.data_sub_acr_name.value}": {
      "auth": "${base64encode("${data.azurerm_key_vault_secret.data_sub_tf_appid.value}:${data.azurerm_key_vault_secret.data_sub_tf_appsecret.value}")}"
    }
  }
}
DOCKER
  }
  type = "kubernetes.io/dockerconfigjson"
}
resource helm_release secret_inject_release {
  depends_on = [ ]

  name      = local.inj_akvs_crd_name
  chart     = "../../../../../charts/akv2k8s/use/akv2k8s-inject"
  namespace = kubernetes_namespace.akv2k8s_test_ns.metadata[0].name
  #version   = "1.0.0"

  set {
    name  = "keyvaultName"
    # This is the Key Vault name:
    value = local.data_sub_kv_name
  }
  set {
    name  = "keyvaultObjectName"
    # This is the Key Vault secret name in Key Vault:
    value = local.data_sub_validate_secret_name
  }

  set {
    name  = "akvsResourceName"
    # Name of the akvs CRD object to create:
    value = local.inj_akvs_crd_name
  }
}

#     / Use test injection
resource helm_release inject_testapp_release {
  depends_on = [ helm_release.secret_inject_release ]

  name      = "secret-inject-testapp"
  chart     = "../../../../../charts/akv2k8s/validate/inject-testapp"
  namespace = kubernetes_namespace.akv2k8s_test_ns.metadata[0].name
  version   = "1.0.0"

  set {
    name  = "akvsResourceName"
    # Name of the akvs CRD object to inject in the pod:
    value = local.inj_akvs_crd_name
  }

  # Use Image from Data sub ACR
  set {
    name  = "image.repository"
    value = "${data.azurerm_key_vault_secret.data_sub_acr_name.value}/external/docker/akv2k8s/env-injection-testapp"
  }
  set {
    name  = "image.tag"
    value = "v2.0.1"
  }
  set {
    name  = "image.pullSecret"
    value = kubernetes_secret.imagepull.metadata[0].name
  }
}

#     / Control result:
#       k get pod -n akv2k8s-test
#       k logs -n akv2k8s-test akvs-secret-app-76dcb54979-6zl8x
#*/

/*
#--------------------------------------------------------------
#   4.: Test Aad Pod Identity
#--------------------------------------------------------------
resource azurerm_user_assigned_identity test_managed_id {
  resource_group_name = data.azurerm_resource_group.aks_nodes_rg.name
  location            = data.azurerm_resource_group.aks_nodes_rg.location

  name = "aks-${replace(lower(var.cluster_name), "-", "")}-aadpodid-test"
}
resource azurerm_role_assignment test_rg_reader {
  scope                = data.azurerm_resource_group.aks_nodes_rg.id
  role_definition_name = "Reader"
  principal_id         = azurerm_user_assigned_identity.test_managed_id.principal_id
}
resource kubernetes_namespace test_ns {
  depends_on = [ azurerm_role_assignment.test_rg_reader ]

  metadata {
    name = "aadpodid-test"
  }
}
resource helm_release test_azid_helmrel {
  name        = "aadpodidtest-azureid"
  chart       = "../../../../../charts/aadpodid/use/azureid"
  namespace   = kubernetes_namespace.test_ns.metadata[0].name
  version     = "1.0.0"

  set {
    name  = "azureManagedIdentity.name"
    value = replace(lower(azurerm_user_assigned_identity.test_managed_id.name), "-", "")
  }
  set {
    name  = "azureManagedIdentity.resourceId"
    value = azurerm_user_assigned_identity.test_managed_id.id
  }
  set {
    name  = "azureManagedIdentity.clientId"
    value = azurerm_user_assigned_identity.test_managed_id.client_id
  }
  set {
    name  = "podSelector"
    value = "test-aadpodid"
  }
}
resource helm_release demopod_helmrel {
  name        = "aadpodidtest-demopod"
  chart       = "../../../../../charts/aadpodid/validate/demopod"
  namespace   = kubernetes_namespace.test_ns.metadata[0].name
  version     = "1.0.0"

  set {
    name  = "subscriptionid"
    value = data.azurerm_client_config.current.subscription_id
  }
  set {
    name  = "clientid"
    value = azurerm_user_assigned_identity.test_managed_id.client_id
  }
  set {
    name  = "resourcegroup"
    value = data.azurerm_resource_group.aks_nodes_rg.name
  }
  set {
    name  = "podSelector"
    value = "test-aadpodid"
  }
}

# Test success:
#     k logs aadpodid-demopod -n aadpodid-test
#     => Should give a list of VM and Ips from the Resource Group
#*/