# Description   : This Terraform resource set is used to:
#                 test the deployment of an Private AKS cluster with Terraform
#
#                   Based on Microsoft tenant limitations, the proces is:
#                   - comment the section starting at the 'resource azurerm_kubernetes_cluster "aks_cluster"' to the end
#                   - run the plan (plan then apply)
#                   - run the az aks command in CreatePrivAksAzCliCmd.sh (set the right values)
#                   - use az aks show to get the cluster [id]
#                   - uncomment the section 'resource azurerm_kubernetes_cluster "aks_cluster"'
#                   - run the command 'tf import azurerm_kubernetes_cluster.aks_cluster [id]'
#                   - uncomment the remaining and launch plan / apply
#
# Directory     : /hub-spoke-privateaks/4-spoke-private-aks/
# Modules       : none
# Created on    : 2020-03-23
# Created by    : Emmanuel
# Last Modified : 2020-04-02
# Prerequisites : terraform 0.12.+, azurerm 2.2.0

# Note: the use of *auto.tfvars* pattern allow variables files auto processing
# If changes in BACKEND     : tf init
# To PLAN an execution      : tf plan
# Then to APPLY this plan   : tf apply -auto-approve
# To DESTROY the resources  : tf destroy

# To REMOVE a resource state: tf state rm 'azurerm_storage_container.tfstatecontainer'
# To IMPORT a resource      : tf import azurerm_storage_container.tfstatecontainer /[id]

terraform {
  backend "azurerm" {
    resource_group_name     = "Hub-BaseServices-RG"
    storage_account_name    = "hubbasesvcstor"
    container_name          = "terraform-states"
        key                 = "4-spoke-private-aks.tfstate"
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
locals {
    timestamp = formatdate("YYYY-MM-DD hh:mm ZZZ", timestamp())
    base_tags = "${map(
        "BuiltBy", "Terraform",
        "TfFolder", "/hub-spoke-privateaks/4-spoke-private-aks/",
        "BuiltOn","${local.timestamp}",
        "InitiatedBy", "EB",
        "RefreshedOn", "${local.timestamp}",        
    )}"
}
#   ===  Data Connections  ===>>
data azurerm_log_analytics_workspace "hub-laws" {
    name                = var.base_laws_name
    resource_group_name = var.base_rg_name
    }
data azurerm_key_vault "hub_kv" {
    name                = var.base_kv_name
    resource_group_name = var.base_rg_name
    }
data azurerm_key_vault_secret "sp_client_id" {
    name         = "private-aks-cluster-sp-id"
    key_vault_id = data.azurerm_key_vault.hub_kv.id
    }
data azurerm_key_vault_secret "sp_client_secret" {
    name         = "private-aks-cluster-sp-secret"
    key_vault_id = data.azurerm_key_vault.hub_kv.id
    }
data azurerm_key_vault_secret "windows-admin-username" {
    name         = "private-aks-winnodes-admin-user"
    key_vault_id = data.azurerm_key_vault.hub_kv.id
    }
data azurerm_key_vault_secret "windows-admin-pwd" {
    name         = "private-aks-winnodes-admin-pwd"
    key_vault_id = data.azurerm_key_vault.hub_kv.id
    }
data azurerm_key_vault_secret "aad_server_id" {
    name         = "private-aks-aad-server-id"
    key_vault_id = data.azurerm_key_vault.hub_kv.id
    }
data azurerm_key_vault_secret "aad_server_secret" {
    name         = "private-aks-aad-server-secret"
    key_vault_id = data.azurerm_key_vault.hub_kv.id
    }
data azurerm_key_vault_secret "aad_client_id" {
    name         = "private-aks-aad-client-id"
    key_vault_id = data.azurerm_key_vault.hub_kv.id
    }
data azurerm_virtual_network "hub_vnet" {
    name                = var.hub_vnet_name
    resource_group_name = var.hub_rg_name
}
#   <<===  End of Data Connections  ===

#   ===  Private AKS VNet  ===
resource azurerm_resource_group aks_rg {
    name     = "${var.aks_base_name}-RG"
    location = "canadacentral"

    tags = local.base_tags
    lifecycle {
        ignore_changes = [
            tags["BuiltOn"],
        ]
    }
    }

resource azurerm_virtual_network aks_vnet {
    name                = "${var.aks_base_name}-NodePools-VNet"
    location            = azurerm_resource_group.aks_rg.location
    resource_group_name = azurerm_resource_group.aks_rg.name
    address_space       = ["10.144.38.0/24"]

    tags = local.base_tags
    lifecycle {
        ignore_changes = [
            tags["BuiltOn"],
        ]
    }
    }

resource azurerm_subnet aks_subnet {
    name                    = "${var.aks_base_name}-DefaultNodePool-Subnet"
    resource_group_name     = azurerm_resource_group.aks_rg.name
    virtual_network_name    = azurerm_virtual_network.aks_vnet.name
    address_prefix          = "10.144.38.0/24"    
    service_endpoints       = [ "Microsoft.KeyVault", "Microsoft.Sql", "Microsoft.ContainerRegistry" ]
    }
resource azurerm_route_table egress_udr {
    name        = "${azurerm_subnet.aks_subnet.name}-Egress-UDR"
    location    = azurerm_virtual_network.aks_vnet.location
    resource_group_name = azurerm_virtual_network.aks_vnet.resource_group_name
    disable_bgp_route_propagation = false

    route {
        name = "egress_to_firewall"
        address_prefix = "0.0.0.0/0"
        next_hop_type = "VirtualAppliance"
        next_hop_in_ip_address = var.hub_fw_ip
    }
    }
resource azurerm_subnet_route_table_association nodesvnet_to_fw {
    subnet_id = azurerm_subnet.aks_subnet.id
    route_table_id = azurerm_route_table.egress_udr.id
}
# Connect the Private AKS VNet to the Hub VNet
resource azurerm_virtual_network_peering "privaks-to-hub" {
    name                            = lower("PrivAks-To-Hub")
    resource_group_name             = azurerm_virtual_network.aks_vnet.resource_group_name
    virtual_network_name            = azurerm_virtual_network.aks_vnet.name
    remote_virtual_network_id       = data.azurerm_virtual_network.hub_vnet.id
    allow_virtual_network_access    = true
    allow_forwarded_traffic         = true
    allow_gateway_transit           = false
    use_remote_gateways             = true
    }
resource azurerm_virtual_network_peering "hub-to-privaks" {
    name                            = lower("Hub-To-PrivAks")
    resource_group_name             = data.azurerm_virtual_network.hub_vnet.resource_group_name
    virtual_network_name            = data.azurerm_virtual_network.hub_vnet.name
    remote_virtual_network_id       = azurerm_virtual_network.aks_vnet.id
    allow_virtual_network_access    = true
    allow_forwarded_traffic         = true
    allow_gateway_transit           = true
    use_remote_gateways             = false
    }


#   ===  Private AKS Cluster  ===
# tf import azurerm_kubernetes_cluster.aks_cluster /subscriptions/08cb517b-02d9-4f23-a5d0-6aa5a2fc65fa/resourcegroups/Spoke-Private-AKS-RG/providers/Microsoft.ContainerService/managedClusters/Spoke-Private-AKS-Cluster
resource azurerm_kubernetes_cluster "aks_cluster" {
    name                        = "${var.aks_base_name}-Cluster"
    location                    = azurerm_resource_group.aks_rg.location
    resource_group_name         = azurerm_resource_group.aks_rg.name
    dns_prefix                  = "hubspoke-privaks-dns"
    kubernetes_version          = "1.15.10"
    node_resource_group         = "${var.aks_base_name}-RG-managed"
    enable_pod_security_policy  = false
    private_link_enabled        = true

    default_node_pool {
        name                    = "defaultpool"
        enable_auto_scaling     = false
        max_pods                = 30
        enable_node_public_ip   = false
        node_count              = 1
        vm_size                 = "Standard_B2s"
        os_disk_size_gb         = 80
        vnet_subnet_id          = azurerm_subnet.aks_subnet.id
        type                    = "VirtualMachineScaleSets"
    }

    network_profile {
        network_plugin      = "azure"
        network_policy      = "calico"
        load_balancer_sku   = "Standard"
        dns_service_ip      = "10.2.0.10"
        service_cidr        = "10.2.0.0/24"
        docker_bridge_cidr  = "172.17.0.1/16"
    }

    addon_profile {
        oms_agent {
            enabled = true
            log_analytics_workspace_id = data.azurerm_log_analytics_workspace.hub-laws.id
        }
        kube_dashboard {
            enabled = true
        }
        // http_application_routing {
        //     enabled = false
        // }
    }

    linux_profile {
        admin_username  = "azureuser"
        ssh_key {
            key_data = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABA...pEv"
        }        
    }

    windows_profile {
        admin_username = data.azurerm_key_vault_secret.windows-admin-username.value
        //admin_password = data.azurerm_key_vault_secret.windows-admin-pwd.value
    }

    service_principal {
        client_id       = data.azurerm_key_vault_secret.sp_client_id.value
        client_secret   = data.azurerm_key_vault_secret.sp_client_secret.value
    }

    role_based_access_control {
         enabled = true

        // azure_active_directory {
        //     server_app_id       = data.azurerm_key_vault_secret.aad_server_id.value
        //     server_app_secret   = data.azurerm_key_vault_secret.aad_server_secret.value
        //     client_app_id       = data.azurerm_key_vault_secret.aad_client_id.value
        // }
    }

    tags = local.base_tags
    lifecycle {
        ignore_changes = [
            tags["BuiltOn"],
        ]
    }
    }


# Link the Private DNS to the Hub VNet for AKS resolution
resource azurerm_private_dns_zone_virtual_network_link "privaks_dnslink" {
    name                  = lower("PrivateAksDns-To-HubVNet-Link")
    resource_group_name   = azurerm_kubernetes_cluster.aks_cluster.node_resource_group
    private_dns_zone_name = "${split(".", azurerm_kubernetes_cluster.aks_cluster.private_fqdn)[1]}.privatelink.${azurerm_kubernetes_cluster.aks_cluster.location}.azmk8s.io"
    virtual_network_id    = data.azurerm_virtual_network.hub_vnet.id
    
    tags = local.base_tags
    lifecycle {
        ignore_changes = [
            tags["BuiltOn"],
        ]
    }
    }
