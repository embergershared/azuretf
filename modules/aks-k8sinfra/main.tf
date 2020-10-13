# Description   : This Terraform creates the kubernetes infrastructure within an AKS Cluster
#                 It deploys:
#                   - Creates the <akscluster>-kubeconfig file from a PowerShell script,
#                   - kured,
#                   - akv2k8s.io linked to out of subscription Key Vault,
#                   - Ingress Controller ([Static] Public IP & Internal LB),
#                   - whoami service,
#                   - NFS Storage server.


# Folder/File   : /modules/aks-k8sinfra/main.tf
# Terraform     : >= 0.13
# Providers     : azurerm, kubernetes,
# Plugins       : none
# Modules       : none
#
# Created on    : 2020-07-16
# Created by    : Emmanuel Bergerat
# Last Modified : 2020-10-06
# Last Modif by : Emmanuel Bergerat
# Modification  : added back kubernetes_namespace to ensure deletion when Helm release is removed

#   To launch the K8S Dashboard:
#az aks browse -g <rg-name> -n <aks-name>

# Notes:
#     - To launch the K8S Dashboard:
#         az aks browse -g <rg-name> -n <aks-name>
#     - Get all Helm releases, whatever their status:
#         helm list --all -A

#--------------------------------------------------------------
#   1.: Terraform Initialization
#--------------------------------------------------------------
locals {
  # kubeconfig access data
  host                     = data.azurerm_kubernetes_cluster.aks_cluster.kube_config[0].host
  client_certificate       = base64decode(data.azurerm_kubernetes_cluster.aks_cluster.kube_config[0].client_certificate)
  client_key               = base64decode(data.azurerm_kubernetes_cluster.aks_cluster.kube_config[0].client_key)
  cluster_ca_certificate   = base64decode(data.azurerm_kubernetes_cluster.aks_cluster.kube_config[0].cluster_ca_certificate)

  # Split name of AKS cluster
  aks_cluster_name_split    = split("-", data.azurerm_kubernetes_cluster.aks_cluster.name)
  # Location short suffix for AKS Cluster
  shortl_cluster_location   = local.aks_cluster_name_split[1]
  # Subscription' Short name
  subs_nickname             = local.aks_cluster_name_split[2]
}
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

#--------------------------------------------------------------
#   2.: Modules Dependencies (In & Out)
#--------------------------------------------------------------
provider null {
  version = "~> 2.1"
}
resource null_resource dependency_modules {
  provisioner "local-exec" {
    command = "echo ${length(var.dependencies)}"
  }
}
resource null_resource k8sinfra_module_completion {
  depends_on = [
    helm_release.kured,
    helm_release.akv2k8s_crd,
    helm_release.akv2k8s_controller,
    helm_release.akv2k8s_envinjector,
    helm_release.ingress_pip_static,
    helm_release.ingress_pip_default,
    helm_release.ingress_azilb,
    helm_release.whoami,
    kubernetes_ingress.www_bca_whoami,
    helm_release.nfs_server,
  ]
  # lifecycle {
  #   create_before_destroy = true
  # }
}

#--------------------------------------------------------------
#   2.: Data collection of required resources (Public IP, AKS & KV connection secrets)
#--------------------------------------------------------------
#   / Ingress static Public IP
data azurerm_public_ip ing_pip {
  depends_on          = [ null_resource.dependency_modules ]
  count               = var.piping_name == "" ? 0 : 1

  name                = lower("pip-${local.shortl_cluster_location}-${local.subs_nickname}-${replace(var.piping_name, "pip", "")}")
  resource_group_name = lower("rg-${local.shortl_cluster_location}-${local.subs_nickname}-aks-networking")
}
#   / AKS Cluster
data azurerm_kubernetes_cluster aks_cluster {
  name                = var.aks_cluster_name
  resource_group_name = var.aks_cluster_rg_name
}
#   / AKS Cluster Nodepool Subbnet
data azurerm_subnet aks_nodespods_subnet {
  name                  = "snet-nodespods"
  virtual_network_name  = "vnet-${local.shortl_cluster_location}-${local.subs_nickname}-aks-${local.aks_cluster_name_split[3]}"
  resource_group_name   = var.aks_cluster_rg_name
}

#   / Service Principal Tenant to access Data subscription
data azurerm_key_vault_secret data_sub_tf_tenantid {
  key_vault_id  = var.aks_sub_kv_id
  name          = var.data_sub_tfsp_tenantid_kvsecret
}
#   / Service Principal Id to access Data subscription
data azurerm_key_vault_secret data_sub_tf_appid {
  key_vault_id  = var.aks_sub_kv_id
  name          = var.data_sub_tfsp_appid_kvsecret
}
#   / Service Principal secret to access Data subscription
data azurerm_key_vault_secret data_sub_tf_appsecret {
  key_vault_id  = var.aks_sub_kv_id
  name          = var.data_sub_tfsp_secret_kvsecret
}


#--------------------------------------------------------------
#   3.: Deploy kured (for Linux nodes automatic reboot)
#--------------------------------------------------------------
#   Ref:  https://docs.microsoft.com/en-us/azure/aks/node-updates-kured
#         https://github.com/weaveworks/kured/tree/master/charts/kured
resource kubernetes_namespace kured_ns {
  depends_on        = [ 
    null_resource.dependency_modules,
    var.dependencies,
  ]

  metadata {
    name = "kured"
  }
}
resource helm_release kured {
  depends_on        = [
    kubernetes_namespace.kured_ns,
  ]

  namespace         = kubernetes_namespace.kured_ns.metadata[0].name

  name              = "kured"   # <= Helm release name
  repository        = "https://weaveworks.github.io/kured"
  chart             = "kured"

  # Additional settings
  cleanup_on_fail       = true  # default= false

  # Ref:  https://github.com/weaveworks/kured/tree/master/charts/kured
  values     = [
    <<EOF
nodeSelector:
  beta.kubernetes.io/os: linux
configuration:
  startTime: 01:00
  endTime: 05:30
  timeZone: America/Toronto
EOF
  ]
}

#--------------------------------------------------------------
#   4.: Deploy akv2k8s
#--------------------------------------------------------------
#   ===  To deploy from Local Chart Sources  ===
# Documentation: https://akv2k8s.io/stable/azure-key-vault-controller/README/#installing-the-chart
# Download the Charts with these commands:
#   helm repo add spv-charts http://charts.spvapi.no
#   helm repo update
#   helm pull spv-charts/azure-key-vault-controller --untar
#   DL: http://charts.spvapi.no/azure-key-vault-controller-1.1.0.tgz
#   helm pull spv-charts/azure-key-vault-env-injector --untar
#   Local Helm repo is here: C:\Users\eb\AppData\Local\Temp\helm\repository
locals {
  akv2k8s_prefix  = "akv2k8s"
}
resource kubernetes_namespace akv2k8s_ns {
  depends_on        = [ helm_release.kured ]

  metadata {
    name = local.akv2k8s_prefix
  }
}
resource helm_release akv2k8s_crd {
  depends_on        = [ kubernetes_namespace.akv2k8s_ns ]

  namespace         = kubernetes_namespace.akv2k8s_ns.metadata[0].name
  name              = "${local.akv2k8s_prefix}-crd"
  # repository        = "https://raw.githubusercontent.com/sparebankenvest/azure-key-vault-to-kubernetes/crd-1.1.0/crds/AzureKeyVaultSecret.yaml"
  chart      = "../../../../../charts/akv2k8s/deploy/akv2k8s-crd"
}

resource helm_release akv2k8s_controller {
  depends_on        = [ helm_release.akv2k8s_crd ]

  namespace         = kubernetes_namespace.akv2k8s_ns.metadata[0].name
  name              = "${local.akv2k8s_prefix}-controller"
  repository        = "http://charts.spvapi.no"
  chart             = "azure-key-vault-controller"

  # Additional settings
  cleanup_on_fail       = true  # default= false
  replace               = true  # default= false
  timeout               = 560   # default= 500

  # Authentication to MSDN Subscription Key Vault
  values = [
<<EOF
keyVault:
  customAuth:
    enabled: true
env:
  AZURE_TENANT_ID: ${data.azurerm_key_vault_secret.data_sub_tf_tenantid.value}
  AZURE_CLIENT_ID: ${data.azurerm_key_vault_secret.data_sub_tf_appid.value}
  AZURE_CLIENT_SECRET: ${data.azurerm_key_vault_secret.data_sub_tf_appsecret.value}
EOF
  ]

  # Logs: kubectl -n akv2k8s logs deployment/akv2k8s-controller-azure-key-vault-controller
}
resource helm_release akv2k8s_envinjector {
  depends_on        = [ helm_release.akv2k8s_controller ]

  namespace         = kubernetes_namespace.akv2k8s_ns.metadata[0].name
  name              = "${local.akv2k8s_prefix}-env-injector"
  repository        = "http://charts.spvapi.no"
  chart             = "azure-key-vault-env-injector"

  # Additional settings
  cleanup_on_fail       = true  # default= false
  replace               = true  # default= false
  timeout               = 560   # default= 500

  # Authentication to MSDN Subscription Key Vault
  values = [
<<EOF
keyVault:
  customAuth:
    enabled: true
webhook:
  env:
    AZURE_TENANT_ID: ${data.azurerm_key_vault_secret.data_sub_tf_tenantid.value}
    AZURE_CLIENT_ID: ${data.azurerm_key_vault_secret.data_sub_tf_appid.value}
    AZURE_CLIENT_SECRET: ${data.azurerm_key_vault_secret.data_sub_tf_appsecret.value}
EOF
  ]
# caBundleController:
#   env:
#     AZURE_TENANT_ID: ${data.azurerm_key_vault_secret.data_sub_tf_tenantid.value}
#     AZURE_CLIENT_ID: ${data.azurerm_key_vault_secret.data_sub_tf_appid.value}
#     AZURE_CLIENT_SECRET: ${data.azurerm_key_vault_secret.data_sub_tf_appsecret.value}

  # Logs: kubectl -n akv2k8s logs deployment/akv2k8s-env-injector-azure-key-vault-env-injector
  # Logs: kubectl -n akv2k8s logs deployment/akv2k8s-env-injector-azure-key-vault-env-injector-ca-bundle
}
#*/

#--------------------------------------------------------------
#   5a.: Deploy ingress nginx on [Pre-existing] Public IP
#--------------------------------------------------------------
# Ref : https://docs.microsoft.com/en-us/azure/aks/static-ip#use-a-static-ip-address-outside-of-the-node-resource-group
# Note: Permissions for the cluster to capture the Public IPs RG (Reader + Network Contributor) => done by AKS module
locals {
  pip_ingress_suffix = var.piping_name == "" ? "default" : lower("pip${local.shortl_cluster_location}${replace(var.piping_name, "pip", "")}") #data.azurerm_public_ip.ing_pip[0].domain_name_label
  nginx_pip_name = "ingress-nginx-${local.pip_ingress_suffix}"

  nginx_shared_yaml     = [
    <<EOF
controller:
  replicaCount: 2
  nodeSelector:
    beta.kubernetes.io/os: linux
  service:
    externalTrafficPolicy: Local
defaultBackend:
  enabled: true
  nodeSelector:
    beta.kubernetes.io/os: linux
EOF
  ]
}
#   / Public IP: Ingress controller via Helm chart
#   Ref: https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release
resource kubernetes_namespace ingress_pip_static {
  count             = var.piping_name == "" ? 0 : 1
  depends_on        = [ 
    helm_release.akv2k8s_envinjector,
    helm_release.akv2k8s_controller,
    data.azurerm_public_ip.ing_pip
  ]

  metadata {
    name = local.nginx_pip_name
  }
}
resource helm_release ingress_pip_static {
  count             = var.piping_name == "" ? 0 : 1

  namespace         = kubernetes_namespace.ingress_pip_static[0].metadata[0].name
  name              = local.nginx_pip_name
  repository        = "https://kubernetes.github.io/ingress-nginx"
  chart             = "ingress-nginx"
  #version           = "3.1.0"

  # Specific options tuning
  verify                = false # default= false
  reuse_values          = false # default= false
  reset_values          = false # default= false
  force_update          = false # default= false
  recreate_pods         = false # default= false
  cleanup_on_fail       = true  # default= false
  skip_crds             = false # default= false
  dependency_update     = false # default= false
  replace               = true  # default= false
  lint                  = false # default= false
  render_subchart_notes = false # default= true
  timeout               = 560   # default= 500

  values     = local.nginx_shared_yaml

  # Settings to capture and use an existing Azure Public IP
  set {
    name  = "controller.service.loadBalancerIP"
    value = data.azurerm_public_ip.ing_pip[0].ip_address
  }
  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/azure-dns-label-name"
    value = data.azurerm_public_ip.ing_pip[0].domain_name_label
  }
  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-resource-group"
    value = data.azurerm_public_ip.ing_pip[0].resource_group_name
  }
}
resource kubernetes_namespace ingress_pip_default {
  count             = var.piping_name == "" ? 1 : 0
  depends_on        = [
    helm_release.akv2k8s_envinjector,
    helm_release.akv2k8s_controller,
  ]

  metadata {
    name = local.nginx_pip_name
  }
}
resource helm_release ingress_pip_default {
  count             = var.piping_name == "" ? 1 : 0
  depends_on        = [ helm_release.ingress_pip_default ]

  namespace         = kubernetes_namespace.ingress_pip_default[0].metadata[0].name
  name              = local.nginx_pip_name
  repository        = "https://kubernetes.github.io/ingress-nginx"
  chart             = "ingress-nginx"

  values     = local.nginx_shared_yaml
}

#--------------------------------------------------------------
#   6.: Deploy ingress nginx on Internal Load Balancer
#--------------------------------------------------------------
# Note: Permissions for the cluster on Nodes RG => done by AKS module
# Ref : https://docs.microsoft.com/en-us/azure/aks/internal-lb
locals {
  split_aks_vnet = split(".", data.azurerm_subnet.aks_nodespods_subnet.address_prefixes[0])
  ilb_ip = "${local.split_aks_vnet[0]}.${local.split_aks_vnet[1]}.${local.split_aks_vnet[2]+15}.${replace(local.split_aks_vnet[3], "0/20", var.ilb_ip_suffix)}"
  nginx_ilb_name = "ingress-nginx-azilb"
}
#   / ILB: Bound Ingress controller
resource kubernetes_namespace ingress_azilb {
  count             = var.deploy_ilb ? 1 : 0
  depends_on        = [
    helm_release.ingress_pip_static,
    helm_release.ingress_pip_default,
  ]

  metadata {
    name = local.nginx_ilb_name
  }
}
resource helm_release ingress_azilb {
  count             = var.deploy_ilb ? 1 : 0
  depends_on        = [ helm_release.ingress_pip_static, helm_release.ingress_pip_default ]

  namespace         = kubernetes_namespace.ingress_azilb[0].metadata[0].name
  name              = local.nginx_ilb_name
  repository        = "https://kubernetes.github.io/ingress-nginx"
  chart             = "ingress-nginx"

  values     = local.nginx_shared_yaml

  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-internal"
    value = "true"
    type  = "string"
  }

  set {
    name  = "controller.service.loadBalancerIP"
    value = local.ilb_ip
  }
}
#*/

/*
#--------------------------------------------------------------
#   7.: Deploy AzureAd Pod Identity
#--------------------------------------------------------------
# Note: if using managed identity in another Resource Group, assign "Managed Identity Operator" role to the AKS cluster on the managed identity or its containing Resource Group

#   / Role assignments (as per: https://github.com/Azure/aad-pod-identity/blob/master/docs/readmes/README.role-assignment.md#role-assignment)
resource azurerm_role_assignment aks_vm_contributor {
  count                   = length(local.aks_principals)

  scope                = local.aks_nodes_rg_id
  role_definition_name = "Virtual Machine Contributor"
  principal_id         = element(local.aks_principals, count.index)_id
}
resource azurerm_role_assignment aks_managedid_operator {
  count                   = length(local.aks_principals)

  scope                = local.aks_nodes_rg_id
  role_definition_name = "Managed Identity Operator"
  principal_id         = element(local.aks_principals, count.index)_id
}

#   / Aad Pod Identity Helm release
#   ===  Deployment from Local Chart Sources  ===
# Note: Download the Charts with these commands:
#   helm repo add aad-pod-identity https://raw.githubusercontent.com/Azure/aad-pod-identity/master/charts
#   helm repo update
#   helm pull aad-pod-identity/aad-pod-identity --untar
resource helm_release aadpodid_helmrel {
  # Ref: https://github.com/Azure/aad-pod-identity/tree/master/charts/aad-pod-identity
  depends_on  = [ azurerm_role_assignment.aks_vm_contributor, azurerm_role_assignment.aks_managedid_operator, helm_release.akv2k8s_envinjector ]

  name        = "aad-pod-identity"
  namespace   = "kube-system" # as per Important note: https://github.com/Azure/aad-pod-identity#1-deploy-aad-pod-identity, we put aad-podidentity in kube-system namespace

  repository  = "https://raw.githubusercontent.com/Azure/aad-pod-identity/master/charts"
  chart       = "aad-pod-identity"
}
#*/

#--------------------------------------------------------------
#   8.: Deploy whoami service
#--------------------------------------------------------------
#   / Whoami Helm release
resource kubernetes_namespace whoami {
  depends_on        = [ helm_release.ingress_pip_static, helm_release.ingress_pip_default, helm_release.ingress_azilb ]

  metadata {
    name = "whoami"
  }
}
resource helm_release whoami {
  # Ref: 
  depends_on        = [ kubernetes_namespace.whoami ]

  namespace         = kubernetes_namespace.whoami.metadata[0].name
  name              = "whoami"
  # repository        = ""
  chart             = "../../../../../charts/whoami"

  # Additional settings
  cleanup_on_fail       = true  # default= false
  replace               = true  # default= false
  timeout               = 560   # default= 500
}
#   / www.bergerat.ca/whoami Ingress rule
resource kubernetes_ingress www_bca_whoami {
  depends_on        = [ helm_release.whoami ]

  metadata {
    name        = "bca-whoami-ingress"
    namespace   = helm_release.whoami.namespace
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
            service_name = helm_release.whoami.name
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
#        / Helm release for stable/nfs-server-provisioner
resource kubernetes_namespace nfs_server {
  depends_on        = [ helm_release.whoami ]

  metadata {
    name = "nfs-storage"
  }
}
resource helm_release nfs_server {
  depends_on        = [ kubernetes_namespace.nfs_server ]

  namespace         = kubernetes_namespace.nfs_server.metadata[0].name
  name              = "nfs-server"
  # repository        = ""
  chart             = "../../../../../charts/nfs-server-provisioner"

  # Additional settings
  cleanup_on_fail       = true  # default= false
  replace               = true  # default= false
  timeout               = 560   # default= 500

  values     = [
    <<EOF
persistence:
  storageClass: default
  enabled: true
  size: 1Gi
EOF
  ]

  # set {
  #   name = "persistence.storageClass"
  #   value = "default"
  # }
  # set {
  #   name = "persistence.enabled"
  #   value = "true"
  # }
  # set {
  #   name = "persistence.size"
  #   value = "1Gi"
  # }
}
#*/