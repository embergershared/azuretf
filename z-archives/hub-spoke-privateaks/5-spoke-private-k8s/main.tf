# Description   : This Terraform resource set is used to:
#
#
# Directory     : /hub-spoke-privateaks/5-spoke-private-k8s/
# Modules       : none
# Created on    : 2020-03-27
# Created by    : Emmanuel
# Last Modified : 2020-04-02
# Prerequisites : terraform 0.12.+, azurerm 2.2.0, kubernetes 1.11.1

# Note: the use of *auto.tfvars* pattern allow variables files auto processing
# If changes in BACKEND     : tf init
# To PLAN an execution      : tf plan
# Then to APPLY this plan   : tf apply -auto-approve
# To DESTROY the resources  : tf destroy

# To REMOVE a resource state: tf state rm 'azurerm_storage_container.tfstatecontainer'
# To IMPORT a resource      : tf import azurerm_storage_container.tfstatecontainer /[id]

terraform {
  backend "azurerm" {
    resource_group_name  = "Hub-BaseServices-RG"
    storage_account_name = "hubbasesvcstor"
    container_name       = "terraform-states"
    key                  = "5-spoke-private-k8s.tfstate"
        }
    }
provider azurerm {
    version         = "=2.2.0"
    features        {}

    tenant_id       = var.tenant_id
    subscription_id = var.subscription_id
    client_id       = var.tf_app_id
    client_secret   = var.tf_app_secret
    }


# Run: "az aks get-credentials -g ${var.aks_cluster_rg} -n ${var.aks_cluster_name} --admin"
#az aks get-credentials -g $cluster-rg -n $cluster-name --admin
# Then run tf plan and apply, so the kubernetes provider can leverage the ~/.kube/config file
provider "kubernetes" {
    version             = "=1.11.1"
    load_config_file    = "true"
}

locals {
    timestamp = formatdate("YYYY-MM-DD hh:mm ZZZ", timestamp())
    base_tags = "${map(
        "BuiltBy", "Terraform",
        "BuiltOn","${local.timestamp}",
        "InitiatedBy", "EB",
        "RefreshedOn", "${local.timestamp}",        
    )}"
    }

#   ===  Test Namespace  ===
resource "kubernetes_namespace" "tftest_ns" {
    metadata {
        name = "terraform-2ndtest"
    }
    }

#   ===  user1 & user2 as Cluster Admin  ===
resource kubernetes_cluster_role_binding "RbacClusterAdmins" {
    for_each = var.aks_cluster_admins_AADIds
    metadata {
        name = "cluster-admin-${each.key}"
    }
    role_ref {
        api_group   = "rbac.authorization.k8s.io"
        kind        = "ClusterRole"
        name        = "cluster-admin"
    }
    subject {
        kind        = "User"
        name        = each.value
        api_group   = "rbac.authorization.k8s.io"
    }
    }