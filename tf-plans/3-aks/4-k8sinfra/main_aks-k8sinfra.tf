# Description   : This Terraform creates the kubernetes infrastructure within an AKS Cluster
#                 It deploys:
#                   - Gather the kubeconfig file from a script
#                   - kured,
#                   - akv2k8s.io,
#                   - Ingress Controller,
#                   - Azure AD Pod Identity,
#                   - whoami service,
#                   - NFS Storage server.
#

# Folder/File   : /tf-plans/3-aks/4-k8sinfra
# Terraform     : 0.13.+
# Providers     : azurerm 2.+
# Plugins       : none
# Modules       : none
#
# Created on    : 2020-06-16
# Created by    : Emmanuel
# Last Modified : 2020-09-03
# Last Modif by : Emmanuel

# Notes:
#     - Command to copy Kube config:
#         > Windows: Copy-Item $home\.kube\config .\kubeconfig
#         > Linux:   cp
#         Don't forget to set the default context to the target cluster / clean the config file content

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
provider azuread {
  version = "~> 0.10.0"

  tenant_id       = var.tenant_id
  subscription_id = var.subscription_id
  client_id       = var.tf_app_id
  client_secret   = var.tf_app_secret
}
provider kubernetes {
  version             = "~>1.11"
  load_config_file    = "true"
  config_path         = "kubeconfig"
}
provider helm {
  version             = "~>1.2.2"
  kubernetes {
    config_path     = "kubeconfig"
  }
}
provider null { 
  version = "~> 2.1"
}
locals {
  # Location short for the AKS Cluster
  shortl_cluster_location  = lookup({
      canadacentral   = "cac",
      canadaeast      = "cae",
      eastus          = "use" },
    lower(var.cluster_location), "")
  shortu_cluster_location = upper(local.shortl_cluster_location)
  shortt_cluster_location = title(local.shortl_cluster_location)
  shortd_cluster_location = local.shortl_cluster_location != "" ? "-${local.shortu_cluster_location}" : ""

  # Location short for Main location
  shortl_main_location  = lookup({
      canadacentral   = "cac", 
      canadaeast      = "cae",
      eastus          = "use" },
    lower(var.main_location), "")

  # Location1 short suffixes for AKS Networking
  shortl_aksnet_location1  = lookup({
      canadacentral   = "cac",
      canadaeast      = "cae",
      eastus          = "use" },
    lower(var.aksnet_location1), "")

  # Location2 short suffixes for AKS Networking
  shortl_aksnet_location2  = lookup({
      canadacentral   = "cac",
      canadaeast      = "cae",
      eastus          = "use" },
    lower(var.aksnet_location2), "")
}

#--------------------------------------------------------------
#   1.: Data collection of required resources (KV, ACR & AKS)
#--------------------------------------------------------------
# data azurerm_client_config current {
# }
#   / Key Vault
data azurerm_key_vault kv_to_use {
  name                  = lower("kv-${local.shortl_main_location}-${var.subs_nickname}-${var.sharedsvc_kv_suffix}")
  resource_group_name   = lower("rg-${local.shortl_main_location}-${var.subs_nickname}-${var.sharedsvc_rg_name}")
}
#   / ACR
data azurerm_container_registry acr_to_use {
  name                  = lower("acr${local.shortl_main_location}${var.subs_nickname}${var.sharedsvc_acr_suffix}") # 5-50 alphanumeric characters
  resource_group_name   = lower("rg-${local.shortl_main_location}-${var.subs_nickname}-${var.sharedsvc_rg_name}")
}
#   / AKS
data azurerm_kubernetes_cluster aks_cluster {
  name                        = lower("aks-${local.shortl_cluster_location}-${var.subs_nickname}-${var.cluster_name}")
  resource_group_name         = lower("rg-${local.shortl_cluster_location}-${var.subs_nickname}-aks-${var.cluster_name}")
}
#   / AKS Managed Resource Group
data azurerm_resource_group aks_nodes_rg {
  name                = data.azurerm_kubernetes_cluster.aks_cluster.node_resource_group
}
#   / AKS Service Principal
data azuread_service_principal aks_sp {
  count           = var.can_create_azure_servprincipals ? 1 : 0

  display_name        = lower("sp-${var.subs_nickname}-gopher194-aks-${var.cluster_name}")
}
#   / Ingress static Public IP 1
data azurerm_public_ip ing_pip1 {
  name                = lower("pip-${local.shortl_cluster_location}-${var.subs_nickname}-${replace(var.piping1_name, "pip", "")}")
  resource_group_name = lower("rg-${local.shortl_cluster_location}-${var.subs_nickname}-aks-networking")
}
#   / Ingress static Public IP 2
data azurerm_public_ip ing_pip2 {
  name                = lower("pip-${local.shortl_cluster_location}-${var.subs_nickname}-${replace(var.piping2_name, "pip", "")}")
  resource_group_name = lower("rg-${local.shortl_cluster_location}-${var.subs_nickname}-aks-networking")
}

#--------------------------------------------------------------
#   2.: Initialize Kube config credentials
#--------------------------------------------------------------
#   / PowerShell to get the kubeconfig file
resource null_resource get_aks_creds {
  provisioner "local-exec" {
    command = "az aks get-credentials -g ${data.azurerm_kubernetes_cluster.aks_cluster.resource_group_name} -n ${data.azurerm_kubernetes_cluster.aks_cluster.name} --admin --overwrite-existing --file kubeconfig"
    interpreter = ["PowerShell", "-Command"]
  }
}
#   / Delay to allow the write disk time of kubeconfig
resource null_resource delay_5s {
  provisioner "local-exec" {
    command = "Start-Sleep -Seconds 5"
    interpreter = ["PowerShell", "-Command"]
  }
  triggers = { "before" = "${null_resource.get_aks_creds.id}" }
}
#*/

#--------------------------------------------------------------
#   3.: Deploy kured (for Linux nodes automatic reboot)
#--------------------------------------------------------------
#   Ref:  https://docs.microsoft.com/en-us/azure/aks/node-updates-kured
resource kubernetes_namespace kured_ns {
  depends_on = [ null_resource.delay_5s ]

  metadata {
    name = "kured"
  }
}
#         https://github.com/helm/charts/tree/master/stable/kured
resource helm_release kured_release {
  depends_on = [ null_resource.get_aks_creds, ]

  name       = "kured"
  chart      = "../../../../../charts/kured"
  namespace  = kubernetes_namespace.kured_ns.metadata[0].name
  version    = "1.4.4"

  set {
    name  = "nodeSelector.beta\\.kubernetes\\.io/os"
    value = "linux"
  }

  # Extra configuration
  # Ref:  https://github.com/weaveworks/kured#configuration
  set {
    name  = "configuration.startTime"
    value = "01:00"
  }
  set {
    name  = "configuration.endTime"
    value = "05:30"
  }
  set {
    name  = "configuration.timeZone"
    value = "America/Toronto"
  }
}

#--------------------------------------------------------------
#   4.: Deploy akv2k8s
#--------------------------------------------------------------
resource kubernetes_namespace akv2k8s_ns {
  depends_on = [ null_resource.delay_5s ]

  metadata {
    name = "akv2k8s"
  }
}

#   ===  Deployment from Local Chart Sources  ===
# Note: Download the Charts with these commands:
#   helm repo add spv-charts http://charts.spvapi.no
#   helm repo update
#   helm pull spv-charts/azure-key-vault-crd --untar
#   helm pull spv-charts/azure-key-vault-controller --untar
#   helm pull spv-charts/azure-key-vault-env-injector --untar

resource helm_release akv2k8s_crd_release {
  depends_on = [ null_resource.get_aks_creds, kubernetes_namespace.akv2k8s_ns ]

  name       = "akv2k8s-crd"
  chart      = "../../../../../charts/akv2k8s/deploy/akv2k8s-crd"
  namespace  = kubernetes_namespace.akv2k8s_ns.metadata[0].name
  version    = "1.0.1"
}
resource helm_release akv2k8s_controller_release {
  # Documentation: https://akv2k8s.io/stable/azure-key-vault-controller/README/#installing-the-chart
  depends_on = [ helm_release.akv2k8s_crd_release ]

  name       = "akv2k8s-controller"
  chart      = "../../../../../charts/akv2k8s/deploy/akv2k8s-controller"
  namespace  = kubernetes_namespace.akv2k8s_ns.metadata[0].name
  version     = "1.0.2"

  set {
    name  = "installCrd"
    value = "false"
  }

  # Use the latest images (default: 1.0.2, latest: latest (1.1.0-beta.32))
  set {
    name  = "image.tag"
    value = "1.0.2"
  }
}
resource helm_release akv2k8s_envinjector_release {
  # Documentation: https://akv2k8s.io/stable/azure-key-vault-env-injector/README/#installing-the-chart
  depends_on = [ helm_release.akv2k8s_crd_release ]

  name       = "akv2k8s-env-injector"
  chart      = "../../../../../charts/akv2k8s/deploy/akv2k8s-env-injector"
  namespace  = kubernetes_namespace.akv2k8s_ns.metadata[0].name
  version     = "1.0.2"

  set {
    name  = "installCrd"
    value = "false"
  }

  # Use the latest images (default are: 1.0.2, latest: latest (1.1.0-beta.32)))
  set {
    name  = "image.tag"
    value = "1.0.2"
  }
  set {
    name  = "envImage.tag"
    value = "1.0.2"
  }
}
/*
Tests:
kns set akv2k8s
k get pod
*/
#*/

#--------------------------------------------------------------
#   5.: Deploy ingress nginx on Static Public IPs
#--------------------------------------------------------------
# Ref : https://docs.microsoft.com/en-us/azure/aks/static-ip#use-a-static-ip-address-outside-of-the-node-resource-group
# Note: Permissions for the cluster to get the Public IPs RG (Reader + Network Contributor) => done by AKS module

/*
#   / PubIP1: Namespace
resource kubernetes_namespace nginx_ing1_ns {
  depends_on = [ null_resource.delay_5s ]

  metadata {
    name = "ingress-${data.azurerm_public_ip.ing_pip1.domain_name_label}"
  }
}
#   / PubIP1: Ingress controller via Helm chart (Loses the X-Forwarded-For)
resource helm_release ingress_nginx_statpip1_release {
  name       = "ingress-nginx-${data.azurerm_public_ip.ing_pip1.domain_name_label}"
  chart      = "../../../../../charts/ingress-nginx"
  namespace  = kubernetes_namespace.nginx_ing1_ns.metadata[0].name
  version     = "0.34.1"

  set {
    name  = "controller.replicaCount"
    value = "2"
  }
  set {
    name  = "controller.nodeSelector.beta\\.kubernetes\\.io/os"
    value = "linux"
  }
  set {
    name  = "defaultBackend.nodeSelector.beta\\.kubernetes\\.io/os"
    value = "linux"
  }
  set {
    name  = "controller.service.loadBalancerIP"
    value = data.azurerm_public_ip.ing_pip1.ip_address
  }
  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/azure-dns-label-name"
    value = data.azurerm_public_ip.ing_pip1.domain_name_label
  }
  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-resource-group"
    value = data.azurerm_public_ip.ing_pip1.resource_group_name
  }
  set {
    name  = "defaultBackend.enabled"
    value = "true"
  }
} */

#   / PubIP1: Ingress controller via module (preserves the X-Forwarded-For - TODO: Find the right nginx configuration with the Helm Chart)
module nginx_ing1_module {
  source              = "../../../../../modules/ingress-nginx"
  namespace_name      = "ingress-${data.azurerm_public_ip.ing_pip1.domain_name_label}"
  image_ref           = "us.gcr.io/k8s-artifacts-prod/ingress-nginx/controller" # "acrcacmsdn.azurecr.io/external/quay/nginx-ingress-controller"
  image_version       = "v0.34.1"   # "v0.30.0"
  controller_replicas_count = 2
  ingress_publicip    = data.azurerm_public_ip.ing_pip1.ip_address
  ingress_dns_prefix  = data.azurerm_public_ip.ing_pip1.domain_name_label
  ingress_pip_rg      = data.azurerm_public_ip.ing_pip1.resource_group_name
}

/*
#   / PubIP2: Namespace
resource kubernetes_namespace nginx_ing2_ns {
  depends_on = [ null_resource.delay_5s ]

  metadata {
    name = "ingress-${data.azurerm_public_ip.ing_pip2.domain_name_label}"
  }
}
#   / PubIP2: Ingress controller via Helm chart (Loses the X-Forwarded-For)
resource helm_release ingress_nginx_statpip2_release {
  name       = "ingress-nginx-${data.azurerm_public_ip.ing_pip2.domain_name_label}"
  chart      = "../../../../../charts/ingress-nginx"
  namespace  = kubernetes_namespace.nginx_ing2_ns.metadata[0].name
  version     = "0.34.1"

  set {
    name  = "controller.replicaCount"
    value = "2"
  }
  set {
    name  = "controller.nodeSelector.beta\\.kubernetes\\.io/os"
    value = "linux"
  }
  set {
    name  = "defaultBackend.nodeSelector.beta\\.kubernetes\\.io/os"
    value = "linux"
  }
  set {
    name  = "controller.service.loadBalancerIP"
    value = data.azurerm_public_ip.ing_pip2.ip_address
  }
  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/azure-dns-label-name"
    value = data.azurerm_public_ip.ing_pip2.domain_name_label
  }
  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-resource-group"
    value = data.azurerm_public_ip.ing_pip2.resource_group_name
  }
  set {
    name  = "defaultBackend.enabled"
    value = "true"
  }
} */

#   / PubIP2: Ingress controller via module (preserves the X-Forwarded-For - TODO: Find the right nginx configuration with the Helm Chart)
module nginx_ing2_module {
  source              = "../../../../../modules/ingress-nginx"
  namespace_name      = "ingress-${data.azurerm_public_ip.ing_pip2.domain_name_label}"
  controller_replicas_count = 2
  image_ref           = "us.gcr.io/k8s-artifacts-prod/ingress-nginx/controller" # "acrcacmsdn.azurecr.io/external/quay/nginx-ingress-controller"
  image_version       = "v0.34.1"   # "v0.30.0"
  ingress_publicip    = data.azurerm_public_ip.ing_pip2.ip_address
  ingress_dns_prefix  = data.azurerm_public_ip.ing_pip2.domain_name_label
  ingress_pip_rg      = data.azurerm_public_ip.ing_pip2.resource_group_name
}
/*
Tests:
kubectl get service -n ingress-pubpip1
kubectl get service -n ingress-pubpip2
*/


#--------------------------------------------------------------
#   6.: Deploy ingress nginx on Azure Internal Load Balancer
#--------------------------------------------------------------
# Note: Permissions for the cluster on Nodes RG => done by AKS module
# Ref : https://docs.microsoft.com/en-us/azure/aks/internal-lb

# Required:
#  in the file \charts\ingress-nginx\templates\controller-service.yaml
#  Add the following lines at the annotation section (line 8):
#     {{- if .Values.controller.service.azInternalLb.use }}
#       annotations:
#         service.beta.kubernetes.io/azure-load-balancer-internal: "true"
#     {{- end }}
#     {{- if .Values.controller.service.azInternalLb.use }}
#         service.beta.kubernetes.io/azure-load-balancer-internal-subnet: "snet-internallb"
#     {{- end }}
/*
#   / ILB1: Namespace
resource kubernetes_namespace nginx_ilb1_ns {
  depends_on = [ null_resource.delay_5s ]

  metadata {
    name = "ingress-ilb1"
  }
}
#   / ILB1: Bound Ingress controller
resource helm_release ingress_nginx_ilb1_release {
  name       = "ingress-nginx-ilb1"
  chart      = "../../../../../charts/ingress-nginx"
  namespace  = kubernetes_namespace.nginx_ilb1_ns.metadata[0].name
  version     = "0.34.1"

  set {
    name  = "controller.replicaCount"
    value = "2"
  }
  set {
    name  = "controller.nodeSelector.beta\\.kubernetes\\.io/os"
    value = "linux"
  }
  set {
    name  = "defaultBackend.nodeSelector.beta\\.kubernetes\\.io/os"
    value = "linux"
  }
  set {
    name  = "defaultBackend.enabled"
    value = "true"
  }

  # Configure the use of the Azure Internal Load Balancer
  set {
    name  = "controller.service.azInternalLb.use"
    value = "true"
  }
  set {
    name  = "controller.service.azInternalLb.subnet"
    value = "snet-internallb"
  }
  set {
    name  = "controller.service.loadBalancerIP"
    value = replace(var.ilb_vnet_cidr, "0/24", "10")
  }
}
#   / ILB2: Namespace
resource kubernetes_namespace nginx_ilb2_ns {
  depends_on = [ null_resource.delay_5s ]

  metadata {
    name = "ingress-ilb2"
  }
}
#   / ILB2: Bound Ingress controller
resource helm_release ingress_nginx_ilb2_release {
  name       = "ingress-nginx-ilb2"
  chart      = "../../../../../charts/ingress-nginx"
  namespace  = kubernetes_namespace.nginx_ilb2_ns.metadata[0].name
  version     = "0.34.1"

  set {
    name  = "controller.replicaCount"
    value = "2"
  }
  set {
    name  = "controller.nodeSelector.beta\\.kubernetes\\.io/os"
    value = "linux"
  }
  set {
    name  = "defaultBackend.nodeSelector.beta\\.kubernetes\\.io/os"
    value = "linux"
  }
  set {
    name  = "defaultBackend.enabled"
    value = "true"
  }

  # Configure the use of the Azure Internal Load Balancer
  set {
    name  = "controller.service.azInternalLb.use"
    value = "true"
  }
  set {
    name  = "controller.service.azInternalLb.subnet"
    value = "snet-internallb"
  }
  set {
    name  = "controller.service.loadBalancerIP"
    value = replace(var.ilb_vnet_cidr, "0/24", "15")
  }
}
#*/


#--------------------------------------------------------------
#   7.: Deploy AzureAd Pod Identity
#--------------------------------------------------------------
# Note: if using managed identity in another Resource Group, assign "Managed Identity Operator" role to the AKS cluster on the managed identity or its containing Resource Group

#   / Role assignments (as per: https://github.com/Azure/aad-pod-identity/blob/master/docs/readmes/README.role-assignment.md#role-assignment)
resource azurerm_role_assignment aks_vm_contributor {
  scope                = data.azurerm_resource_group.aks_nodes_rg.id
  role_definition_name = "Virtual Machine Contributor"
  principal_id         = var.can_create_azure_servprincipals ? data.azuread_service_principal.aks_sp[0].object_id : var.aks_sp_objid
}
resource azurerm_role_assignment aks_managedid_operator {
  scope                = data.azurerm_resource_group.aks_nodes_rg.id
  role_definition_name = "Managed Identity Operator"
  principal_id         = var.can_create_azure_servprincipals ? data.azuread_service_principal.aks_sp[0].object_id : var.aks_sp_objid
}

#   / Aad Pod Identity Namespace 
resource kubernetes_namespace aadpodid_ns {
  depends_on = [ null_resource.delay_5s ]

  metadata {
    name = "aadpodid"
  }
}
#   / Aad Pod Identity Helm release
resource helm_release aadpodid_helmrel {
  # Ref: https://github.com/Azure/aad-pod-identity/tree/master/charts/aad-pod-identity
  depends_on  = [ azurerm_role_assignment.aks_vm_contributor, azurerm_role_assignment.aks_managedid_operator ]

  name        = "aadpodid-2.0-release"
  chart       = "../../../../../charts/aadpodid"
  #namespace   = "kube-system" # as per Important note: https://github.com/Azure/aad-pod-identity#1-deploy-aad-pod-identity, we put aad-podidentity in kube-system namespace
  namespace   = kubernetes_namespace.aadpodid_ns.metadata[0].name
  version     = "2.0.0"
}


#--------------------------------------------------------------
#   8.: Deploy a whoami service
#--------------------------------------------------------------
#   / Whoami Namespace 
resource kubernetes_namespace whoami_ns {
  metadata {
    name = "whoami"
  }
}
#   / Whoami Helm release
resource helm_release whoami_helmrel {
  # Ref: 

  name        = "whoami-release"
  chart       = "../../../../../charts/whoami"
  namespace   = kubernetes_namespace.whoami_ns.metadata[0].name
  version     = "1.0.0"
}
#   / Production TheLightCircle Whoami Ingress rule
resource kubernetes_ingress prod_tlc_whoami_ingress {
  metadata {
    name        = "bca-whoami-ingress"
    namespace   = kubernetes_namespace.whoami_ns.metadata[0].name
    annotations = {
      # use the shared ingress-nginx
      "kubernetes.io/ingress.class" = "nginx"
      
      # nginx automatically redirects http to https. This can be disabled with:
      "nginx.ingress.kubernetes.io/ssl-redirect" = "false"
      
      # To redirect / to www:
      "nginx.ingress.kubernetes.io/from-to-www-redirect" = "true"
      
      # To enforce a redirect to Https, when SSL is offloaded to reverse proxy:
      # "nginx.ingress.kubernetes.io/force-ssl-redirect" = "true"
    }
  }

  spec {
    # tls {
    #   hosts = [ "www.bergerat.ca" ]
    #   secret_name = "tlc-ssl"
    #   # Secret created as: https://kubernetes.github.io/ingress-nginx/examples/PREREQUISITES/#tls-certificates
    # }
    rule {
      host = "www.bergerat.ca"
      http {
        path {
          path = "/whoami"
          backend {
            service_name = helm_release.whoami_helmrel.name
            service_port = 80
          }
        }
      }
    }
  }
}


#--------------------------------------------------------------
#   9.: Deploy Persistent NFS storage
#--------------------------------------------------------------
#        / Namespace
resource kubernetes_namespace nfs_ns {
  metadata {
    name = "nfs-storage"
  }
}
#        / Helm release for stable/nfs-server-provisioner
resource helm_release nfs_helmrel {
  name        = "nfs-provisioner-server"
  chart       = "../../../../../charts/nfs-server-provisioner"
  namespace   = kubernetes_namespace.nfs_ns.metadata[0].name

  set {
    name = "persistence.storageClass"
    value = "default"
  }
  set {
    name = "persistence.enabled"
    value = "true"
  }
  set {
    name = "persistence.size"
    value = "10Gi"
  }
}
#*/