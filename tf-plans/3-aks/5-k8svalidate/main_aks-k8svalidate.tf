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
#     - Ensure the Helm repo spvest is present on host:
#       "Helm repo add spvest http://charts.spvapi.no"

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
module main_shortloc {
  source    = "../../../../../modules/shortloc"
  location  = var.main_location
}
locals {
  # Plan Tag value
  tf_plan   = "/tf-plans/3-aks/5-k8svalidate/main_aks-k8svalidate.tf"

  # Location short for AKS Cluster location
  shortl_cluster_location  = module.aks_shortloc.code

  # kubeconfig access data
  host                     = data.azurerm_kubernetes_cluster.aks_cluster.kube_config[0].host
  client_certificate       = base64decode(data.azurerm_kubernetes_cluster.aks_cluster.kube_config[0].client_certificate)
  client_key               = base64decode(data.azurerm_kubernetes_cluster.aks_cluster.kube_config[0].client_key)
  cluster_ca_certificate   = base64decode(data.azurerm_kubernetes_cluster.aks_cluster.kube_config[0].cluster_ca_certificate)
}
module aks_shortloc {
  source    = "../../../../../modules/shortloc"
  location  = var.cluster_location
}

#--------------------------------------------------------------
#   2.: Data collection of required resources (KV, ACR & AKS)
#--------------------------------------------------------------
#   / AKS
data azurerm_kubernetes_cluster aks_cluster {
  name                        = lower("aks-${local.shortl_cluster_location}-${var.subs_nickname}-${var.cluster_name}")
  resource_group_name         = lower("rg-${local.shortl_cluster_location}-${var.subs_nickname}-aks-${var.cluster_name}")
}
data azurerm_resource_group aks_nodes_rg {
  name                = data.azurerm_kubernetes_cluster.aks_cluster.node_resource_group
}

#--------------------------------------------------------------
#   3.: Test akv2k8s
#--------------------------------------------------------------
locals {
  kv_name       = var.validate_kv_name    
  secret_name   = var.validate_secret_name
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
  sync_akvs_crd_name = "${local.secret_name}-sync"
}
resource helm_release secret_sync_release {
  depends_on = [ ]

  name      = local.sync_akvs_crd_name
  chart     = "../../../../../charts/akv2k8s/use/akv2k8s-syncsecret"
  namespace = kubernetes_namespace.akv2k8s_test_ns.metadata[0].name
  version   = "1.0.0"

  set {
    name  = "keyvaultName"
    # This is the Key Vault name:
    value = local.kv_name
  }
  set {
    name  = "keyvaultObjectName"
    # This is the Key Vault secret name in Key Vault:
    value = local.secret_name
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
#       k -n akv2k8s-test get secret k8s-validate-annecy-secret-sync -o yaml
#       echo 'SWYgeW91IHNlZSB0aGlzIHNlY3JldCwgaXQgd29ya2VkIQ==' | base64 --decode
#       => should display the secret value text "This string is the value of the test ..."


#   / Testing Secret Injection (the Injector+Env)
#     / Deploy test injection
locals {
  inj_akvs_crd_name = "${local.secret_name}-inj"
}
resource helm_release secret_inject_release {
  depends_on = [ ]

  name      = local.inj_akvs_crd_name
  chart     = "../../../../../charts/akv2k8s/use/akv2k8s-injectsecret"
  namespace = kubernetes_namespace.akv2k8s_test_ns.metadata[0].name
  #version   = "1.0.0"

  set {
    name  = "keyvaultName"
    # This is the Key Vault name:
    value = local.kv_name
  }
  set {
    name  = "keyvaultObjectName"
    # This is the Key Vault secret name in Key Vault:
    value = local.secret_name
  }

  set {
    name  = "akvsResourceName"
    # Name of the akvs CRD object to create:
    value = local.inj_akvs_crd_name
  }
}

# Debug a Helm chart:
# helm install --debug --dry-run aks-veyrier-secret-inj ../validate/akv2k8s-injecttestapp --namespace akv2k8s-test --set akvsResourceName=k8s-validate-veyrier-secret-inj

# Ensure akvk8s Helm repo update
resource null_resource helm_repo_update {
  provisioner "local-exec" {
    interpreter = ["PowerShell", "-Command"]
    command     = "Helm repo update"
  }
}

#     / Use test injection
resource helm_release inject_testapp_release {
  depends_on = [ helm_release.secret_inject_release ]

  name      = "secret-inj-testapp"
  chart     = "../../../../../charts/akv2k8s/validate/akv2k8s-injecttestapp"
  namespace = kubernetes_namespace.akv2k8s_test_ns.metadata[0].name
  version   = "1.0.0"

  set {
    name  = "akvsResourceName"
    # Name of the akvs CRD object to inject in the pod:
    value = local.inj_akvs_crd_name
  }
}

#     / Control result:
#       k get pod -n akv2k8s-test
#       k logs -n akv2k8s-test akvs-secret-app-6f7b5dcd96-dwbhr
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