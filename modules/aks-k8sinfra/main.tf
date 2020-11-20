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
# Last Modified : 2020-11-07
# Last Modif by : Emmanuel Bergerat
# Modification  : Put data sub pulling out of module + added image+Pullsecret for kured

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
  module_tags = merge(var.base_tags, "${map(
    "TfModule", "/modules/aks-k8sinfra/main.tf",
  )}")

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
    kubernetes_ingress.www_whoami,
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
#   / AKS Cluster VNet
data azurerm_virtual_network aks_vnet {
  name                = "vnet-${local.shortl_cluster_location}-${local.subs_nickname}-aks-${local.aks_cluster_name_split[3]}"
  #name                = ${replace(data.azurerm_kubernetes_cluster.aks_cluster.default_node_pool[0].vnet_subnet_id, "/subnets/snet-nodespods", ""}
  resource_group_name = data.azurerm_kubernetes_cluster.aks_cluster.resource_group_name
}
#   / AKS Cluster Nodepool Subnet
data azurerm_subnet aks_nodespods_subnet {
  name                  = "snet-nodespods"
  virtual_network_name  = data.azurerm_virtual_network.aks_vnet.name
  resource_group_name   = data.azurerm_kubernetes_cluster.aks_cluster.resource_group_name
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
    name = "k8sinfra-kured"
  }
}
resource kubernetes_secret kured_imagepull {
  metadata {
    name      = "acr-imagepull"
    namespace = kubernetes_namespace.kured_ns.metadata[0].name
  }

  data = {
    ".dockerconfigjson" = <<DOCKER
{
  "auths": {
    "${var.data_sub_acr_name}": {
      "auth": "${base64encode("${var.data_sub_access_sp_appid}:${var.data_sub_access_sp_secret}")}"
    }
  }
}
DOCKER
  }
  type = "kubernetes.io/dockerconfigjson"
}
resource helm_release kured {
  # Update Kured Helm chart:
  # helm repo add kured https://weaveworks.github.io/kured
  # helm repo update
  # helm pull kured/kured --untar
  # Remove-Item D:\GitAzDevOps\emwito\AzureInfra\Terraform\charts\kured
  # Move-Item -Path ./kured -Destination D:\GitAzDevOps\emwito\AzureInfra\Terraform\charts   

  depends_on        = [
    kubernetes_namespace.kured_ns,
  ]

  namespace         = kubernetes_namespace.kured_ns.metadata[0].name

  name              = "kured"   # <= Helm release name
  chart      = "../../../../../charts/kured"

  # Additional settings
  cleanup_on_fail       = true  # default= false

  set {
    name  = "image.repository"
    value = "${var.data_sub_acr_name}/external/docker/kured"
  }
  set {
    name  = "image.tag"
    value = "v1.5.0"
  }
  set {
    name  = "image.pullSecrets[0].name"
    value = kubernetes_secret.kured_imagepull.metadata[0].name
  }
  set {
    name  = "image.pullPolicy"
    value = "Always"
  }

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
#   4.: AKS VNet connection to Hub VNet Private DNS for Private Endpoints use to access Data Sub
#--------------------------------------------------------------
#   / Link AKS Cluster VNet to Hub Networking Private DNS Zones for Key Vault
resource azurerm_private_dns_zone_virtual_network_link vault_azure_net-link {
  name                  = "vault.azure.net-to-${replace(data.azurerm_virtual_network.aks_vnet.name, "-", "_")}-link"
  resource_group_name   = var.privdns_rg_name
  private_dns_zone_name = "vault.azure.net"
  virtual_network_id    = data.azurerm_virtual_network.aks_vnet.id
  registration_enabled  = false
  tags                  = local.module_tags
}
resource azurerm_private_dns_zone_virtual_network_link vaultcore_azure_net-link {
  name                  = "vaultcore.azure.net-to-${replace(data.azurerm_virtual_network.aks_vnet.name, "-", "_")}-link"
  resource_group_name   = var.privdns_rg_name
  private_dns_zone_name = "vaultcore.azure.net"
  virtual_network_id    = data.azurerm_virtual_network.aks_vnet.id
  registration_enabled  = false
  tags                  = local.module_tags
}

#   / Link AKS Cluster VNet to Hub Networking Private DNS Zones for Storage account
resource azurerm_private_dns_zone_virtual_network_link file_core_windows_net-link {
  name                  = "file.core.windows.net-to-${replace(data.azurerm_virtual_network.aks_vnet.name, "-", "_")}-link"
  resource_group_name   = var.privdns_rg_name
  private_dns_zone_name = "file.core.windows.net"
  virtual_network_id    = data.azurerm_virtual_network.aks_vnet.id
  registration_enabled  = false
  tags                  = local.module_tags
}
resource azurerm_private_dns_zone_virtual_network_link privatelink_file_core_windows_net-link {
  name                  = "privatelink.file.core.windows.net-to-${replace(data.azurerm_virtual_network.aks_vnet.name, "-", "_")}-link"
  resource_group_name   = var.privdns_rg_name
  private_dns_zone_name = "privatelink.file.core.windows.net"
  virtual_network_id    = data.azurerm_virtual_network.aks_vnet.id
  registration_enabled  = false
  tags                  = local.module_tags
}



#   / Link AKS Cluster VNet to Hub Networking Private DNS Zones for ACR



#--------------------------------------------------------------
#   5.: Deploy akv2k8s
#--------------------------------------------------------------
/*  ===  To deploy from Local Chart Sources  ===
Documentation: https://akv2k8s.io/stable/azure-key-vault-controller/README/#installing-the-chart
Download the Charts with these commands:
  helm repo add spv-charts http://charts.spvapi.no
  helm repo update
  helm pull spv-charts/azure-key-vault-controller --untar
  DL: http://charts.spvapi.no/azure-key-vault-controller-1.1.0.tgz
  helm pull spv-charts/azure-key-vault-env-injector --untar
  Local Helm repo is here: C:\Users\eb\AppData\Local\Temp\helm\repository #*/

locals {
  akv2k8s_prefix    = "akv2k8s"
  data_sub_kv_name  = split("/", var.data_sub_kv_id)[8]
}
#   / Akv2k8s
resource kubernetes_namespace akv2k8s_ns {
  depends_on        = [ helm_release.kured ]

  metadata {
    name = "k8sinfra-${local.akv2k8s_prefix}"
  }
}
resource kubernetes_secret akv2k8s_imagepull {
  metadata {
    name      = "acr-imagepull"
    namespace = kubernetes_namespace.akv2k8s_ns.metadata[0].name
  }

  data = {
    ".dockerconfigjson" = <<DOCKER
{
  "auths": {
    "${var.data_sub_acr_name}": {
      "auth": "${base64encode("${var.data_sub_access_sp_appid}:${var.data_sub_access_sp_secret}")}"
    }
  }
}
DOCKER
  }
  type = "kubernetes.io/dockerconfigjson"
}
resource helm_release akv2k8s_crd {
  depends_on        = [ kubernetes_namespace.akv2k8s_ns ]

  namespace         = kubernetes_namespace.akv2k8s_ns.metadata[0].name
  name              = "${local.akv2k8s_prefix}-crd"
  # repository        = "https://raw.githubusercontent.com/sparebankenvest/azure-key-vault-to-kubernetes/crd-1.1.0/crds/AzureKeyVaultSecret.yaml"
  chart      = "../../../../../charts/akv2k8s/deploy/akv2k8s-crd"
}
resource helm_release akv2k8s_controller {
  # helm repo add akv2k8s http://charts.spvapi.no
  # helm repo update
  # helm pull akv2k8s/azure-key-vault-controller --untar
  # Remove-Item D:\GitAzDevOps\emwito\AzureInfra\Terraform\charts\akv2k8s\deploy\azure-key-vault-controller
  # Move-Item -Path ./azure-key-vault-controller -Destination D:\GitAzDevOps\emwito\AzureInfra\Terraform\charts\akv2k8s\deploy

  depends_on = [ helm_release.akv2k8s_crd ]

  namespace  = kubernetes_namespace.akv2k8s_ns.metadata[0].name
  name       = "${local.akv2k8s_prefix}-controller"
  chart      = "../../../../../charts/akv2k8s/deploy/azure-key-vault-controller"

  # Additional settings
  cleanup_on_fail       = true  # default= false
  replace               = true  # default= false
  timeout               = 560   # default= 500

  # Authentication to Data Subscription Key Vault values
  set {
    name  = "keyVault.customAuth.enabled"
    value = "true"
  }
  set {
    name  = "env.AZURE_TENANT_ID"
    value = var.data_sub_access_sp_tenantid
  }
  set {
    name  = "env.AZURE_CLIENT_ID"
    value = var.data_sub_access_sp_appid
  }
  set {
    name  = "env.AZURE_CLIENT_SECRET"
    value = var.data_sub_access_sp_secret
  }

  # Use Image from Data sub ACR
  set {
    name  = "image.repository"
    value = "${var.data_sub_acr_name}/external/docker/akv2k8s/azure-keyvault-controller"
  }
  set {
    name  = "image.tag"
    value = "v1.1.0"
  }
  set {
    name  = "image.pullSecret"
    value = kubernetes_secret.akv2k8s_imagepull.metadata[0].name
  }

  # Logs: kubectl -n akv2k8s logs deployment/akv2k8s-controller-azure-key-vault-controller
}
resource helm_release akv2k8s_envinjector {
  # helm repo add akv2k8s http://charts.spvapi.no
  # helm repo update
  # helm pull akv2k8s/azure-key-vault-env-injector --untar
  # Remove-Item D:\GitAzDevOps\emwito\AzureInfra\Terraform\charts\akv2k8s\deploy\azure-key-vault-env-injector
  # Move-Item -Path ./azure-key-vault-env-injector -Destination D:\GitAzDevOps\emwito\AzureInfra\Terraform\charts\akv2k8s\deploy

  depends_on = [ helm_release.akv2k8s_controller ]

  namespace  = kubernetes_namespace.akv2k8s_ns.metadata[0].name
  name       = "${local.akv2k8s_prefix}-env-injector"
  chart      = "../../../../../charts/akv2k8s/deploy/azure-key-vault-env-injector"

  # Additional settings
  cleanup_on_fail       = true  # default= false
  #replace               = true  # default= false
  timeout               = 560   # default= 500

  # Injector Webhook Authentication to Data Subscription Key Vault values
  set {
    name  = "keyVault.customAuth.enabled"
    value = "true"
  }
  set {
    name  = "webhook.env.AZURE_TENANT_ID"
    value = var.data_sub_access_sp_tenantid
  }
  set {
    name  = "webhook.env.AZURE_CLIENT_ID"
    value = var.data_sub_access_sp_appid
  }
  set {
    name  = "webhook.env.AZURE_CLIENT_SECRET"
    value = var.data_sub_access_sp_secret
  }
  # caBundleController:
  #   env:
  #     AZURE_TENANT_ID: ${var.data_sub_access_sp_tenantid}
  #     AZURE_CLIENT_ID: ${var.data_sub_access_sp_appid}
  #     AZURE_CLIENT_SECRET: ${var.data_sub_access_sp_secret}

  # Use Images from Data sub ACR
  # / CA bundle controller
  set {
    name  = "caBundleController.image.repository"
    value = "${var.data_sub_acr_name}/external/docker/akv2k8s/ca-bundle-controller"
  }
  set {
    name  = "caBundleController.image.tag"
    value = "v1.1.0"
  }
  # Requires the addition of:
      # {{- if .Values.caBundleController.image.pullSecret }}
      # imagePullSecrets:
      # - name: "{{ .Values.caBundleController.image.pullSecret }}"
      # {{- end }} # in /templates/deployment.yaml / inserted line 88
  set {
    name  = "caBundleController.image.pullSecret"
    value = kubernetes_secret.akv2k8s_imagepull.metadata[0].name
  }

  # / Webhook controller + env
  set {
    name  = "image.repository"
    value = "${var.data_sub_acr_name}/external/docker/akv2k8s/azure-keyvault-webhook"
  }
  set {
    name  = "image.tag"
    value = "v1.1.10"
  }
  # Requires the addition of:
      # {{- if .Values.image.pullSecret }}
      # imagePullSecrets:
      # - name: {{ .Values.image.pullSecret }}
      # {{- end }} # in /templates/deployment.yaml / inserted line 222
  set {
    name  = "image.pullSecret"
    value = kubernetes_secret.akv2k8s_imagepull.metadata[0].name
  }
  set {
    name  = "envImage.repository"
    value = "${var.data_sub_acr_name}/external/docker/akv2k8s/azure-keyvault-env"
  }
  set {
    name  = "envImage.tag"
    value = "v1.1.1"
  }

  # Logs: kubectl -n akv2k8s logs deployment/akv2k8s-env-injector-azure-key-vault-env-injector
  # Logs: kubectl -n akv2k8s logs deployment/akv2k8s-env-injector-azure-key-vault-env-injector-ca-bundle
}
#*/

#--------------------------------------------------------------
#   6.: Deploy ingress nginx on [Pre-existing] Public IP
#--------------------------------------------------------------
# Ref : https://docs.microsoft.com/en-us/azure/aks/static-ip#use-a-static-ip-address-outside-of-the-node-resource-group
# Note: Permissions for the cluster to capture the Public IPs RG (Reader + Network Contributor) => done by AKS module
locals {
  pip_ingress_suffix = var.piping_name == "" ? "default" : lower("pip${local.shortl_cluster_location}${replace(var.piping_name, "pip", "")}") #data.azurerm_public_ip.ing_pip[0].domain_name_label
  nginx_pip_name = "ing${local.pip_ingress_suffix}"

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
resource kubernetes_namespace ingress_ns {
  depends_on        = [ 
    helm_release.akv2k8s_envinjector,
    helm_release.akv2k8s_controller,
    data.azurerm_public_ip.ing_pip
  ]

  metadata {
    name = "k8sinfra-${local.nginx_pip_name}"
  }
}
resource kubernetes_secret pip_ingress_imagepull {
  metadata {
    name      = "acr-imagepull"
    namespace = kubernetes_namespace.ingress_ns.metadata[0].name
  }

  data = {
    ".dockerconfigjson" = <<DOCKER
{
  "auths": {
    "${var.data_sub_acr_name}": {
      "auth": "${base64encode("${var.data_sub_access_sp_appid}:${var.data_sub_access_sp_secret}")}"
    }
  }
}
DOCKER
  }
  type = "kubernetes.io/dockerconfigjson"
}
resource helm_release ingress_pip_static {
  # helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
  # helm repo update
  # helm pull ingress-nginx/ingress-nginx --untar
  # Remove-Item D:\GitAzDevOps\emwito\AzureInfra\Terraform\charts\ingress-nginx
  # Move-Item -Path ./ingress-nginx -Destination D:\GitAzDevOps\emwito\AzureInfra\Terraform\charts

  count      = var.piping_name == "" ? 0 : 1

  namespace  = kubernetes_namespace.ingress_ns.metadata[0].name
  name       = local.nginx_pip_name
  chart      = "../../../../../charts/ingress-nginx"

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

  # Pull images from ACR
  # / Controller
  set {
    name  = "controller.image.repository"
    value = "${var.data_sub_acr_name}/external/k8sgcrio/ingress-nginx/controller"
  }
  set {
    name  = "controller.image.tag"
    value = "v0.41.0"
  }
  # Requires the addition of:
      # {{- if .Values.controller.image.pullSecret }}
      # imagePullSecrets:
      # - name: {{ .Values.controller.image.pullSecret }}
      # {{- end }} 
      # in these files:
      #   /templates/controller-deployment.yaml / inserted line 258
      #   /templates/controller-daemonset.yaml  / inserted line 254
      #   /templates/admission-webhooks/job-patch/job-createSecret.yaml / inserted line 60
      #   /templates/admission-webhooks/job-patch/job-patchWebhook.yaml / inserted line 62
      #   /templates/default-backend-deployment.yaml / inserted line 103
  set {
    name  = "controller.image.pullSecret"
    value = kubernetes_secret.pip_ingress_imagepull.metadata[0].name
  }
  # / Admission Webhooks
  set {
    name  = "controller.admissionWebhooks.image.repository"
    value = "${var.data_sub_acr_name}/external/k8sgcrio/ingress-nginx/jettech-kube-webhook-certgen"
  }
  set {
    name  = "controller.admissionWebhooks.image.tag"
    value = "v1.5.0"
  }

  # / Default Backend
  set {
    name  = "defaultBackend.image.repository"
    value = "${var.data_sub_acr_name}/external/k8sgcrio/ingress-nginx/defaultbackend-amd64"
  }
  set {
    name  = "defaultBackend.image.tag"
    value = "v1.5"
  }
}

resource helm_release ingress_pip_default {
  count      = var.piping_name == "" ? 1 : 0

  namespace  = kubernetes_namespace.ingress_ns.metadata[0].name
  name       = local.nginx_pip_name
  chart      = "../../../../../charts/ingress-nginx"

  values     = local.nginx_shared_yaml

  # Pull images from ACR
  # / Controller
  set {
    name  = "controller.image.repository"
    value = "${var.data_sub_acr_name}/external/k8sgcrio/ingress-nginx/controller"
  }
  set {
    name  = "controller.image.tag"
    value = "v0.41.0"
  }
  set {
    name  = "controller.image.pullSecret"
    value = kubernetes_secret.pip_ingress_imagepull.metadata[0].name
  }
  # / Admission Webhooks
  set {
    name  = "controller.admissionWebhooks.image.repository"
    value = "${var.data_sub_acr_name}/external/k8sgcrio/ingress-nginx/jettech-kube-webhook-certgen"
  }
  set {
    name  = "controller.admissionWebhooks.image.tag"
    value = "v1.5.0"
  }

  # / Default Backend
  set {
    name  = "defaultBackend.image.repository"
    value = "${var.data_sub_acr_name}/external/k8sgcrio/ingress-nginx/defaultbackend-amd64"
  }
  set {
    name  = "defaultBackend.image.tag"
    value = "v1.5"
  }
}


#--------------------------------------------------------------
#   7.: Deploy ingress nginx on Internal Load Balancer
#--------------------------------------------------------------
# Note: Permissions for the cluster on Nodes RG => done by AKS module
# Ref : https://docs.microsoft.com/en-us/azure/aks/internal-lb
locals {
  split_aks_vnet = split(".", data.azurerm_subnet.aks_nodespods_subnet.address_prefixes[0])
  ilb_ip = "${local.split_aks_vnet[0]}.${local.split_aks_vnet[1]}.${local.split_aks_vnet[2]+15}.${replace(local.split_aks_vnet[3], "0/20", var.ilb_ip_suffix)}"
  nginx_ilb_name = "ingazilb"
}
#   / ILB: Bound Ingress controller
resource kubernetes_namespace ingress_azilb {
  count             = var.deploy_ilb ? 1 : 0
  depends_on        = [
    helm_release.ingress_pip_static,
    helm_release.ingress_pip_default,
  ]

  metadata {
    name = "k8sinfra-${local.nginx_ilb_name}"
  }
}
resource kubernetes_secret azilb_ingress_imagepull {
  count      = var.deploy_ilb ? 1 : 0

  metadata {
    name      = "acr-imagepull"
    namespace  = kubernetes_namespace.ingress_azilb[0].metadata[0].name
  }

  data = {
    ".dockerconfigjson" = <<DOCKER
{
  "auths": {
    "${var.data_sub_acr_name}": {
      "auth": "${base64encode("${var.data_sub_access_sp_appid}:${var.data_sub_access_sp_secret}")}"
    }
  }
}
DOCKER
  }
  type = "kubernetes.io/dockerconfigjson"
}
resource helm_release ingress_azilb {
  count      = var.deploy_ilb ? 1 : 0
  depends_on = [ helm_release.ingress_pip_static, helm_release.ingress_pip_default ]

  namespace  = kubernetes_namespace.ingress_azilb[0].metadata[0].name
  name       = local.nginx_ilb_name
  chart      = "../../../../../charts/ingress-nginx"

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

  # Pull images from ACR
  # / Controller
  set {
    name  = "controller.image.repository"
    value = "${var.data_sub_acr_name}/external/k8sgcrio/ingress-nginx/controller"
  }
  set {
    name  = "controller.image.tag"
    value = "v0.41.0"
  }
  set {
    name  = "controller.image.pullSecret"
    value = kubernetes_secret.azilb_ingress_imagepull[0].metadata[0].name
  }
  # / Admission Webhooks
  set {
    name  = "controller.admissionWebhooks.image.repository"
    value = "${var.data_sub_acr_name}/external/k8sgcrio/ingress-nginx/jettech-kube-webhook-certgen"
  }
  set {
    name  = "controller.admissionWebhooks.image.tag"
    value = "v1.5.0"
  }

  # / Default Backend
  set {
    name  = "defaultBackend.image.repository"
    value = "${var.data_sub_acr_name}/external/k8sgcrio/ingress-nginx/defaultbackend-amd64"
  }
  set {
    name  = "defaultBackend.image.tag"
    value = "v1.5"
  }
}
#*/

/*
#--------------------------------------------------------------
#   8.: Deploy AzureAd Pod Identity
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
#   9.: Deploy whoami service
#--------------------------------------------------------------
#   / Whoami Helm release
resource kubernetes_namespace whoami {
  depends_on        = [ helm_release.ingress_pip_static, helm_release.ingress_pip_default, helm_release.ingress_azilb ]

  metadata {
    name = "k8sinfra-whoami"
  }
}
resource kubernetes_secret whoami_imagepull {
  metadata {
    name      = "acr-imagepull"
    namespace  = kubernetes_namespace.whoami.metadata[0].name
  }

  data = {
    ".dockerconfigjson" = <<DOCKER
{
  "auths": {
    "${var.data_sub_acr_name}": {
      "auth": "${base64encode("${var.data_sub_access_sp_appid}:${var.data_sub_access_sp_secret}")}"
    }
  }
}
DOCKER
  }
  type = "kubernetes.io/dockerconfigjson"
}
resource helm_release whoami {
  # Ref: Helm chart Created by Emmanuel
  depends_on        = [ kubernetes_namespace.whoami ]

  namespace         = kubernetes_namespace.whoami.metadata[0].name
  name              = "whoami"
  chart             = "../../../../../charts/whoami"

  # Additional settings
  cleanup_on_fail       = true  # default= false
  replace               = true  # default= false
  timeout               = 560   # default= 500

  # Use Image from Data sub ACR
  set {
    name  = "image.repository"
    value = "${var.data_sub_acr_name}/external/docker/whoami"
  }
  set {
    name  = "image.tag"
    value = "v1.5.0"
  }
  set {
    name  = "image.pullSecret"
    value = kubernetes_secret.whoami_imagepull.metadata[0].name
  }
}
#   / allhosts/whoami Ingress rule
resource kubernetes_ingress www_whoami {
  depends_on        = [ helm_release.whoami ]

  metadata {
    name        = "whoami-ingress"
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
      #host = "www.bergerat.ca"
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
#   10.: Deploy Persistent NFS storage
#--------------------------------------------------------------
  # helm repo add stable https://kubernetes-charts.storage.googleapis.com/
  # helm repo update
  # helm pull stable/nfs-server-provisioner --untar
  # Remove-Item D:\GitAzDevOps\emwito\AzureInfra\Terraform\charts\nfs-server-provisioner
  # Move-Item -Path ./nfs-server-provisioner -Destination D:\GitAzDevOps\emwito\AzureInfra\Terraform\charts

#        / Helm release for stable/nfs-server-provisioner
resource kubernetes_namespace nfs_server {
  depends_on        = [ helm_release.whoami ]

  metadata {
    name = "k8sinfra-nfsstorage"
  }
}
resource kubernetes_secret nfs_server {
  metadata {
    name      = "acr-imagepull"
    namespace  = kubernetes_namespace.nfs_server.metadata[0].name
  }

  data = {
    ".dockerconfigjson" = <<DOCKER
{
  "auths": {
    "${var.data_sub_acr_name}": {
      "auth": "${base64encode("${var.data_sub_access_sp_appid}:${var.data_sub_access_sp_secret}")}"
    }
  }
}
DOCKER
  }
  type = "kubernetes.io/dockerconfigjson"
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

  set {
    name = "persistence.storageClass"
    value = "default" # High Performance SSD: managed-premium
  }
  set {
    name = "persistence.enabled"
    value = "true"
  }
  set {
    name = "persistence.size"
    value = "16Gi"
  }

  # Use Image from Data sub ACR
  set {
    name  = "image.repository"
    value = "${var.data_sub_acr_name}/external/quayio/nfs-provisioner"
  }
  set {
    name  = "image.tag"
    value = "v2.3.0"
  }
  # Requires the addition of:
      # {{- if .Values.image.pullSecret }}
      # imagePullSecrets:
      # - name: {{ .Values.image.pullSecret }}
      # {{- end }} 
      # in these files:
      #   /templates/statefulset.yaml / inserted line 124
  set {
    name  = "image.pullSecret"
    value = kubernetes_secret.nfs_server.metadata[0].name
  }
}
#*/