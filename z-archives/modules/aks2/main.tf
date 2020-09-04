# Description   : This Terraform resource set is used to:
#                 test the deployment of an Private AKS cluster with Terraform
#
# Directory     : /modules/aks/
# Terraform     : 0.12.+
# Providers     : azurerm 2.+
# Plugins       : none
# Modules       : none
# Created on    : 2020-04-08
# Created by    : Emmanuel
# Last Modified : 2020-04-21
# Last Modif by : Emmanuel


terraform {
  required_providers {
    azurerm = ">= 2.7.0"
  }
}


locals {
  timestamp = formatdate("YYYY-MM-DD hh:mm ZZZ", timestamp())
  base_tags = "${map(
      "BuiltBy", "Terraform",
      "TfPlan", "/modules/aks2/main.tf",
      "CallingFolder", "${var.calling_folder}",
      "BuiltOn","${local.timestamp}",
      "InitiatedBy", "EmBerger",
  )}"

  # Location short for Base Services
  shortl_base_location  = lookup({
    canadacentral   = "cac", 
    canadaeast      = "cae",
    eastus          = "use" },
    lower(var.base_rg_location), "")
  shortu_base_location = upper(local.shortl_base_location)
  shortd_base_location = local.shortl_base_location != "" ? "-${local.shortu_base_location}" : ""

  # Location short for Shared Services
  shortl_sharedsvc_location  = lookup({
    canadacentral   = "cac", 
    canadaeast      = "cae",
    eastus          = "use" },
    lower(var.sharedsvc_location), "")
  shortu_sharedsvc_location = upper(local.shortl_sharedsvc_location)
  shortt_sharedsvc_location = title(local.shortl_sharedsvc_location)
  shortd_sharedsvc_location = local.shortl_sharedsvc_location != "" ? "-${local.shortu_sharedsvc_location}" : ""

  # Location short for AKS Cluster
  shortl_aks_location  = lookup({
    canadacentral   = "cac", 
    canadaeast      = "cae",
    eastus          = "use" },
    lower(var.aks_location), "")
  shortu_aks_location = upper(local.shortl_aks_location)
  shortt_aks_location = title(local.shortl_aks_location)
  shortd_aks_location = local.shortl_aks_location != "" ? "-${local.shortu_aks_location}" : ""

  aks_vnet = "${var.aks_vnet_1stIP}/20"
  ilb_subnet = replace(local.aks_vnet, "0.0/20", "16.0/24")
}

#--------------------------------------------------------------
# Data grabbing
#--------------------------------------------------------------
#        / Current context
data azurerm_client_config current {
}
#        / Hub Base
data azurerm_storage_account backendstoracct {
    resource_group_name = "${var.subs_nickname}-${var.base_rg_name}-RG"
    name                = replace(lower("${var.subs_nickname}${var.base_rg_name}stacct${local.shortu_base_location}"), "-", "")
}
#        / Hub Shared Services
data azurerm_log_analytics_workspace "hub-laws" {
    name                = "${var.subs_nickname}-${var.sharedsvc_laws_name}-CAC"
    resource_group_name = "${var.subs_nickname}-${var.sharedsvc_rg_name}-RG-CAC"
    }
data azurerm_key_vault "hub_kv" {
    name                = "${var.subs_nickname}-${var.sharedsvc_kv_name}${local.shortd_sharedsvc_location}"
    resource_group_name = "${var.subs_nickname}-${var.sharedsvc_rg_name}-RG${local.shortd_sharedsvc_location}"
    }
data azurerm_key_vault_secret "sp_client_id" {
    name         = lower("${var.subs_nickname}-${var.account_nickname}-aks-cluster-sp-id")
    key_vault_id = data.azurerm_key_vault.hub_kv.id
    }
data azurerm_key_vault_secret "sp_client_secret" {
    name         = lower("${var.subs_nickname}-${var.account_nickname}-aks-cluster-sp-secret")
    key_vault_id = data.azurerm_key_vault.hub_kv.id
    }
data azurerm_key_vault_secret "windows-admin-username" {
    name         = lower("${var.subs_nickname}-${var.account_nickname}-aks-cluster-winadmin-user")
    key_vault_id = data.azurerm_key_vault.hub_kv.id
    }
data azurerm_key_vault_secret "windows-admin-pwd" {
    name         = lower("${var.subs_nickname}-${var.account_nickname}-aks-cluster-winadmin-pwd")
    key_vault_id = data.azurerm_key_vault.hub_kv.id
    }
data azurerm_key_vault_secret "aad_server_id" {
    name         = lower("${var.subs_nickname}-${var.account_nickname}-aks-cluster-aad-server-id")
    key_vault_id = data.azurerm_key_vault.hub_kv.id
    }
data azurerm_key_vault_secret "aad_server_secret" {
    name         = lower("${var.subs_nickname}-${var.account_nickname}-aks-cluster-aad-server-secret")
    key_vault_id = data.azurerm_key_vault.hub_kv.id
    }
data azurerm_key_vault_secret "aad_client_id" {
    name         = lower("${var.subs_nickname}-${var.account_nickname}-aks-cluster-aad-client-id")
    key_vault_id = data.azurerm_key_vault.hub_kv.id
    }

#   ===  AKS Cluster VNet  ===
resource azurerm_resource_group aks_rg {
  name     = "${var.subs_nickname}-${var.aks_base_name}-RG${local.shortd_aks_location}"
  location = var.aks_location

  tags = merge(local.base_tags, "${map(
    "RefreshedOn", "${local.timestamp}",
  )}")
  lifecycle {
    ignore_changes = [
      tags["BuiltOn"],
    ]
  }
}

resource azurerm_virtual_network aks_vnet {
  name                = "${var.subs_nickname}-${var.aks_base_name}-Cluster-VNet"
  location            = azurerm_resource_group.aks_rg.location
  resource_group_name = azurerm_resource_group.aks_rg.name
  address_space       = [ local.aks_vnet, local.ilb_subnet ]

  tags = local.base_tags
  lifecycle {
    ignore_changes = [
      tags,
    ]
  }
}
#   ===  / AKS VNet Diag setting
module vnet_diag {
  source              = "../diagsettings/vnet"
  subs_nickname       = var.subs_nickname
  base_rg_name        = var.base_rg_name
  #base_rg_location    = var.base_rg_location
  sharedsvc_location  = var.sharedsvc_location
  sharedsvc_rg_name   = var.sharedsvc_rg_name
  sharedsvc_laws_name = var.sharedsvc_laws_name
  
  # AKS VNet Diag Setting instance specific
  base_rg_location    = azurerm_virtual_network.aks_vnet.location
  vnet_name           = azurerm_virtual_network.aks_vnet.name
  vnet_id             = azurerm_virtual_network.aks_vnet.id
}

resource azurerm_subnet aks_nodepool_subnet {
  name                    = "Nodes-Subnet"
  resource_group_name     = azurerm_resource_group.aks_rg.name
  virtual_network_name    = azurerm_virtual_network.aks_vnet.name
  address_prefixes        = [ local.aks_vnet ]
  service_endpoints       = [ "Microsoft.KeyVault", "Microsoft.Sql", "Microsoft.ContainerRegistry", "Microsoft.Storage" ]
}

resource azurerm_subnet aks_internallb_subnet {
  name                    = "InternalLB-Subnet"
  resource_group_name     = azurerm_resource_group.aks_rg.name
  virtual_network_name    = azurerm_virtual_network.aks_vnet.name
  address_prefixes        = [ local.ilb_subnet ]
}

#   ===  Production AKS Cluster  ===
# After creation, the cluster was in Failed state.
# Importing the cluster in the Terraform state:
# tf import azurerm_kubernetes_cluster.aks_cluster /subscriptions/08cb517b-02d9-4f23-a5d0-6aa5a2fc65fa/resourcegroups/Spoke-Private-AKS-RG/providers/Microsoft.ContainerService/managedClusters/Spoke-Private-AKS-Cluster (example for Private cluster created with az aks create)
# Then, re-run a Terraform Apply, fixed the problem
#
#   Terraform provider: https://www.terraform.io/docs/providers/azurerm/r/kubernetes_cluster.html
#
#   Best reference for AKS: https://registry.terraform.io/providers/hashicorp/azurerm/2.9.0/docs/resources/kubernetes_cluster
#
resource azurerm_kubernetes_cluster aks_cluster {
  name                        = "${var.subs_nickname}-${var.aks_base_name}-Cluster"
  location                    = azurerm_resource_group.aks_rg.location
  resource_group_name         = azurerm_resource_group.aks_rg.name
  dns_prefix                  = lower("${var.subs_nickname}-${var.aks_base_name}")
  kubernetes_version          = var.aks_version
  node_resource_group         = "${azurerm_resource_group.aks_rg.name}-managed"
  enable_pod_security_policy  = false  # Needs the preview feature enabled: "Microsoft.ContainerService/PodSecurityPolicyPreview": az feature register --name PodSecurityPolicyPreview --namespace Microsoft.ContainerService
  private_cluster_enabled     = var.aks_enable_privatelink

  default_node_pool {
    name                    = "linuxpool"   # lowercase, letters & numbers: for windows max6, linux max12
    enable_auto_scaling     = false         # if enabled, as node subnet is /20, 250 pods max per nodes leads to 16 nodes max
    max_pods                = 250           # max pods per nodes with advanced networking / basic: 110 max
    enable_node_public_ip   = false
    node_count              = var.aks_nodecount
    vm_size                 = var.aks_nodesize
    os_disk_size_gb         = 80
    vnet_subnet_id          = azurerm_subnet.aks_nodepool_subnet.id
    type                    = "VirtualMachineScaleSets"
  }

  network_profile {
    network_plugin      = "azure"
    network_policy      = "calico"          # https://docs.microsoft.com/en-us/azure/aks/use-network-policies
    load_balancer_sku   = "Standard"
    dns_service_ip      = "10.2.0.10"
    service_cidr        = "10.2.0.0/24"
    docker_bridge_cidr  = "172.17.0.1/16"
    outbound_type       = "loadBalancer"    # or "userDefinedRouting"
  }

  addon_profile {
    oms_agent {
      enabled = true
      log_analytics_workspace_id = data.azurerm_log_analytics_workspace.hub-laws.id
    }
    kube_dashboard {
      enabled = var.aks_dashboard
    }
    http_application_routing {
      enabled = var.aks_devspaces
      # When Enabled, it creates a dedicated DNS zone in the Managed RG
    }
  }

  linux_profile {
    admin_username  = "azureuser"
    ssh_key {
      key_data = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDit/AX10lHKTgqIF0/LUx3eRd5zki96IwziavpK0JaDdygG6gIzvX8ERSt+Dm3K8DvskBM1ma3uYP7vYV30xgzriQbodnVjcUtzb3nw+X9qV1FwJ7Sdmcayp+spUI0kr9S0gul9LJxG9IjTU7TWPLd03na4hvKimSyoULnUniiIu57uo9uZ22FfcO8xRKh1uOY3a0/k21ozV+hGCHpuY3PJEDFeR1+y6/RuzI84XpFZvtQ77Dr1ffs6K5KRWIeOCAkD9rKrk2D8iQbn+wB+0ILHd3Fx8+/qB2Xr3ZQnY7E/hUFXDCspyQX90sWcdAhgXEN1+cqvXzRkx/If3dfqpEv"        
    }        
  }

  windows_profile {
    admin_username = data.azurerm_key_vault_secret.windows-admin-username.value
    admin_password = data.azurerm_key_vault_secret.windows-admin-pwd.value
  }

  identity {
    type = "SystemAssigned"
  }

  role_based_access_control {
    enabled = true

    # Commented as AzureAD Integration denied in Microsoft Tenant
    # azure_active_directory {
    #   server_app_id       = data.azurerm_key_vault_secret.aad_server_id.value
    #   server_app_secret   = data.azurerm_key_vault_secret.aad_server_secret.value
    #   client_app_id       = data.azurerm_key_vault_secret.aad_client_id.value
    # }
  }

  tags = local.base_tags
  lifecycle {
    ignore_changes = [ tags, ]
  }
}
#**/

#   ===  / AKS Cluster Diag setting
module aks_diag {
  source              = "../diagsettings/akscluster"
  subs_nickname       = var.subs_nickname
  base_rg_name        = var.base_rg_name
  sharedsvc_location  = var.sharedsvc_location
  sharedsvc_rg_name   = var.sharedsvc_rg_name
  sharedsvc_laws_name = var.sharedsvc_laws_name
  
  # AKS Cluster Diag Setting instance specific
  base_rg_location    = azurerm_kubernetes_cluster.aks_cluster.location
  aks_name            = azurerm_kubernetes_cluster.aks_cluster.name
  aks_id              = azurerm_kubernetes_cluster.aks_cluster.id
}

#   ===  Peer AKS VNet to the Hub VNet
data azurerm_virtual_network hub_vnet {
  name                = "${var.subs_nickname}-${var.hub_vnet_base_name}-VNet${local.shortd_sharedsvc_location}"
  resource_group_name = "${var.subs_nickname}-${var.hub_vnet_base_name}-RG${local.shortd_sharedsvc_location}"
}
resource azurerm_virtual_network_peering "aks-to-hub" {
  name                            = lower("${azurerm_virtual_network.aks_vnet.name}-To-HubVNet")
  resource_group_name             = azurerm_virtual_network.aks_vnet.resource_group_name
  virtual_network_name            = azurerm_virtual_network.aks_vnet.name
  remote_virtual_network_id       = data.azurerm_virtual_network.hub_vnet.id
  allow_virtual_network_access    = true
  allow_forwarded_traffic         = true
  allow_gateway_transit           = false
  use_remote_gateways             = false
}
resource azurerm_virtual_network_peering "hub-to-aks" {
  name                            = lower("HubVNet-To-${azurerm_virtual_network.aks_vnet.name}")
  resource_group_name             = data.azurerm_virtual_network.hub_vnet.resource_group_name
  virtual_network_name            = data.azurerm_virtual_network.hub_vnet.name
  remote_virtual_network_id       = azurerm_virtual_network.aks_vnet.id
  allow_virtual_network_access    = true
  allow_forwarded_traffic         = true
  allow_gateway_transit           = true
  use_remote_gateways             = false
}
#**/


#   ===  Give the AKS Cluster SP the Network Contributor Role on the AKS RG
#           Required to deploy an Internal Load Balancer
resource azurerm_role_assignment akssp_netwcontrib_aksrg {
  scope                   = azurerm_resource_group.aks_rg.id
  role_definition_name    = "Network Contributor"
  principal_id            = var.aks_sp_oid    # => Must be the Enterprise Appliction Object Id of the AKS Cluster SP!!!
}
/**
#   ===  Give the AKS Cluster SP the Contributor Role on the Data RG
#           Required for AKS to be able to use Azure Static disks and mount them
resource azurerm_role_assignment AksSP_DataRG_contributor {
  scope                    = var.data_rg_id
  role_definition_name     = "Contributor"
  principal_id             = var.aks_sp_oid    # => Must be the Enterprise Appliction Object Id of the AKS Cluster SP!!!
}
#**/

#   ===  Connect the Private AKS Link to DNS (if aks_enable_privatelink == true)
resource azurerm_private_dns_zone_virtual_network_link "privaks_dnslink" {
  count                   = var.aks_enable_privatelink ? 1 : 0
  name                    = "PrivateAksDns-To-HubVNet-Link"
  resource_group_name     = azurerm_kubernetes_cluster.aks_cluster.node_resource_group
  private_dns_zone_name   = "${split(".", azurerm_kubernetes_cluster.aks_cluster.private_fqdn)[1]}.privatelink.${azurerm_kubernetes_cluster.aks_cluster.location}.azmk8s.io"
  virtual_network_id      = data.azurerm_virtual_network.hub_vnet.id
}

#   ===  Azure Firewall connection (if aks_connect_to_azfw == true)
data azurerm_firewall hub_azfw {
  count               = var.aks_connect_to_azfw ? 1 : 0
  name                = "${var.subs_nickname}-${var.hub_vnet_base_name}-AzFirewall${local.shortd_sharedsvc_location}"
  resource_group_name = data.azurerm_virtual_network.hub_vnet.resource_group_name
}
resource azurerm_route_table egress_udr {
  count                           = var.aks_connect_to_azfw ? 1 : 0
  name                            = "${azurerm_subnet.aks_nodepool_subnet.name}-Egress-UDR"
  location                        = azurerm_virtual_network.aks_vnet.location
  resource_group_name             = azurerm_virtual_network.aks_vnet.resource_group_name
  disable_bgp_route_propagation   = false

  route {
    name                    = "egress_to_firewall"
    address_prefix          = "0.0.0.0/0"
    next_hop_type           = "VirtualAppliance"
    next_hop_in_ip_address  = data.azurerm_firewall.hub_azfw[0].ip_configuration[0].private_ip_address
  }
}
resource azurerm_subnet_route_table_association nodesvnet_to_fw {
  count           = var.aks_connect_to_azfw ? 1 : 0
  subnet_id       = azurerm_subnet.aks_nodepool_subnet.id
  route_table_id  = azurerm_route_table.egress_udr[0].id
}
#   ===  Allow AKS NodePool to talk to AKS master
resource azurerm_firewall_application_rule_collection Allow_Nodes_To_AKSMaster {
  count               = var.aks_connect_to_azfw ? 1 : 0
  name                = "ApplicationRule-Allow-NodesSubnet-To-AKSMaster"
  azure_firewall_name = data.azurerm_firewall.hub_azfw[0].name
  resource_group_name = data.azurerm_firewall.hub_azfw[0].resource_group_name
  priority            = 200
  action              = "Allow"

  rule {
    name = "NodesSubnet_Https443_to_AKSMasterPlane"
    source_addresses = [ azurerm_subnet.aks_nodepool_subnet.address_prefix , ]
    target_fqdns = [ azurerm_kubernetes_cluster.aks_cluster.fqdn ]
    protocol {
      port = "443"
      type = "Https"
    }
  }
}
#         Check the nodes are registered: k get nodes --all-namespaces
#          & the system pods are running: k get pods --all-namespaces
#**/

/**
#   ===  Allow AKS Service Principal to Access Key Vault
#            / for user: gopher194@hotmail.com
resource azurerm_key_vault_access_policy AksSpKvAccessGet {
    key_vault_id    = data.azurerm_key_vault.hub_kv.id
    tenant_id       = data.azurerm_client_config.current.tenant_id
    object_id       = var.aks_sp_oid

    key_permissions = [
        "get", //"list", "update", "create", "import", "delete", "recover", "backup", "restore",
        # Cryptographic options
        //"decrypt", "encrypt", "unwrapKey", "wrapKey", "verify", "sign",
        # Privileged key options
        //"purge",
    ]

    secret_permissions = [
        "get", //"list", "set", "delete", "recover", "backup", "restore",
        # Privileged key options
        //"purge",
    ]

    certificate_permissions = [
        "get", //"list", "update", "create", "import", "delete", "recover", "backup", "restore",
        # Certificates specific
        //"managecontacts", "manageissuers", "getissuers", "listissuers", "setissuers", "deleteissuers",
        # Privileged key options
        //"purge",
    ]
}
#**/