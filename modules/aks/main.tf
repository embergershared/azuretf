# Description   : This Terraform module creates an AKS Cluster
#                 It deploys:
#                   - 1 AKS Resource Group,
#                   - 1 VNet / 2 subnets:
#                     - 1 Subnet for NodePool(s),
#                     - 1 Subnet for Azure Internal Load Balancer,
#                   - 1 AKS cluster,
#                   - Required permissions for the AKS Cluster's Service Principal,
#                   - VNet Peering with a Hub VNet.

# Folder/File   : /modules/aks/main.tf
# Terraform     : >= 0.12
# Providers     : azurerm, kubernetes,
# Plugins       : none
# Modules       : none
#
# Created on    : 2020-07-16
# Created by    : Emmanuel Bergerat
# Last Modified : 2020-09-04
# Last Modif by : Emmanuel Bergerat
# Modification  : Tuning for publishing

# AKS Specifics:
#   To get the Credentials:
#az aks get-credentials -g <RGName> -n <AKSClusterName> --admin
#
#   To launch the K8S Dashboard:
#az aks browse -g <RGName> -n <AKSClusterName>

#--------------------------------------------------------------
#   Terraform Initialization
#--------------------------------------------------------------
locals {
  # Dates formatted
  now           = timestamp()
  nowUTC        = formatdate("YYYY-MM-DD hh:mm ZZZ", local.now)  # 2020-06-16 14:44 UTC

  module_tags = merge(var.base_tags, "${map(
    "TfModule", "/modules/aks/main.tf",
    "KubeVersion", "${var.k8s_version}"
  )}")

  # Location short suffix for AKS Cluster
  shortl_cluster_location  = lookup({
      canadacentral   = "cac", 
      canadaeast      = "cae",
      eastus          = "use" },
    lower(var.cluster_location), "")
}

#--------------------------------------------------------------
#   Data collection of required resources
#--------------------------------------------------------------
data azurerm_client_config current {
}

#--------------------------------------------------------------
#   AKS Resource Group
#--------------------------------------------------------------
resource azurerm_resource_group aks_rg {
  name        = lower("rg-${local.shortl_cluster_location}-${var.subs_nickname}-aks-${var.cluster_name}")
  location    = var.cluster_location

  tags = merge(local.module_tags, "${map(
    "RefreshedOn", "${local.nowUTC}",
  )}")
  lifecycle { ignore_changes = [tags["BuiltOn"]] }
}

#--------------------------------------------------------------
#   AKS Networking
#--------------------------------------------------------------
resource azurerm_virtual_network aks_vnet { 
  name                    = lower("vnet-${local.shortl_cluster_location}-${var.subs_nickname}-aks-${var.cluster_name}")
  location                = azurerm_resource_group.aks_rg.location
  resource_group_name     = azurerm_resource_group.aks_rg.name
  address_space           = [ var.aks_vnet_cidr, var.ilb_vnet_cidr ]

  tags = local.module_tags
  lifecycle { ignore_changes = [ tags ] }
}
resource azurerm_subnet aks_nodespods_subnet {
  name                    = "snet-nodespods"
  resource_group_name     = azurerm_resource_group.aks_rg.name
  virtual_network_name    = azurerm_virtual_network.aks_vnet.name
  enforce_private_link_endpoint_network_policies = var.enable_privcluster
  address_prefixes        = [ var.aks_vnet_cidr ]
  service_endpoints       = [ "Microsoft.KeyVault", "Microsoft.Sql",
                              "Microsoft.ContainerRegistry", "Microsoft.Storage" ]
}
resource azurerm_subnet aks_internallb_subnet {
  name                    = "snet-internallb"
  resource_group_name     = azurerm_resource_group.aks_rg.name
  virtual_network_name    = azurerm_virtual_network.aks_vnet.name
  address_prefixes        = [ var.ilb_vnet_cidr ]
}

#--------------------------------------------------------------
#   AKS Cluster
#--------------------------------------------------------------
# Ref: https://docs.microsoft.com/en-us/cli/azure/aks?view=azure-cli-latest#az-aks-create
resource azurerm_kubernetes_cluster cluster {
  name                        = lower("aks-${local.shortl_cluster_location}-${var.subs_nickname}-${var.cluster_name}")
  location                    = azurerm_resource_group.aks_rg.location
  dns_prefix                  = replace(lower("aks-${local.shortl_cluster_location}-${var.subs_nickname}-${var.cluster_name}"), "-", "")
  resource_group_name         = azurerm_resource_group.aks_rg.name
  kubernetes_version          = var.k8s_version        # check with: az aks get-versions --location canadacentral --output table
  node_resource_group         = "${azurerm_resource_group.aks_rg.name}-managed"
  enable_pod_security_policy  = var.enable_podsecurpol           # Needs the preview feature enabled: "Microsoft.ContainerService/PodSecurityPolicyPreview": az feature register --name PodSecurityPolicyPreview --namespace Microsoft.ContainerService
  private_cluster_enabled     = var.enable_privcluster
  api_server_authorized_ip_ranges = var.load_balancer_sku == "Basic" ? null : [ var.authorized_ips ]

  # We don't use Managed Identity because: akv2k8s injector is not compatible yet, Key Vault + ACR logins/access will be easier
  # identity{
  #   type= "SystemAssigned"
  # }
  service_principal {
    client_id     = var.aks_sp_id
    client_secret = var.aks_sp_secret
  }

  role_based_access_control{
    enabled = "true"
    # azure_active_directory {
    #   server_app_id       = data.azurerm_key_vault_secret.aad_server_id.value
    #   server_app_secret   = data.azurerm_key_vault_secret.aad_server_secret.value
    #   client_app_id       = data.azurerm_key_vault_secret.aad_client_id.value
    # }
  }

  default_node_pool {
    name                  = var.default_np_name
    vm_size               = var.default_np_vmsize
    os_disk_size_gb       = var.default_np_osdisksize
    type                  = var.default_np_type
    enable_node_public_ip = var.default_np_enablenodepubip
    vnet_subnet_id        = azurerm_subnet.aks_nodespods_subnet.id

    enable_auto_scaling   = var.default_np_enableautoscale
    node_count            = var.default_np_nodecount
    # max_count             = 15
    # min_count             = 3

    max_pods              = var.default_np_maxpods    # The network used is azure (cni): 30 is default, max is 250 | kubenet: 110
  }

  linux_profile {
    # FYI: Image reference= microsoft-aks / aks / aks-ubuntu-1604-202004 / 2020.04.06   # AKSUbuntu:1604:2020.05.13
    admin_username = var.linx_admin_user
    ssh_key {
      key_data = file(var.linx_ssh_pubkey_path)
    }
  }

  # windows_profile {
  #   admin_username = data.azurerm_key_vault_secret.windows-admin-username.value
  #   admin_password = data.azurerm_key_vault_secret.windows-admin-pwd.value
  # }

  network_profile {
    network_plugin    = var.network_plugin
    network_policy    = var.network_policy
    outbound_type     = var.outbound_type
    load_balancer_sku = var.load_balancer_sku
    # dns_service_ip      = "10.2.0.10"
    # service_cidr        = "10.2.0.0/24"
    # docker_bridge_cidr  = "172.17.0.1/16"
  }

  addon_profile {
    oms_agent {
      enabled = var.enable_omsagent
      log_analytics_workspace_id = var.laws_id
    }
    http_application_routing {
      enabled = var.enable_devspaces
      # When Enabled, it creates a dedicated DNS zone in the Managed RG + additional Public IP
    }
    kube_dashboard {
      enabled = var.enable_kdash
    }
    azure_policy {
      enabled = var.enable_azpolicy
    }
    aci_connector_linux {
      enabled = var.enable_aci
    }
  }

  tags = local.module_tags
  lifecycle { ignore_changes = [ tags, linux_profile[0].ssh_key[0].key_data, ] }
}

#--------------------------------------------------------------
#   Set Cluster Admins
#--------------------------------------------------------------
resource kubernetes_cluster_role_binding RbacClusterAdmins {
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

#--------------------------------------------------------------
#   Required permissions for the AKS Cluster Service Principal
#--------------------------------------------------------------
#   / Reader on the ACR 
#     => Required to pull images
resource azurerm_role_assignment akssp_reader_acr {
  scope                   = var.acr_id
  role_definition_name    = "Reader"
  principal_id            = var.aks_sp_objid
}

#   / Contributor on the AKS Cluster RG
#     => Required for AKS to:
#     - use Azure Static disks and mount them
#     - deploy an Internal Load Balancer (Network Contributor is enough)
resource azurerm_role_assignment akssp_contributor_aksrg {
  scope                   = azurerm_resource_group.aks_rg.id
  role_definition_name    = "Contributor"
  principal_id            = var.aks_sp_objid
}

#   / Access Policy "Get" to Key Vault
#     => Required for k8s & pods to pull secrets
resource azurerm_key_vault_access_policy akssp_accessget_kv {
  key_vault_id    = var.secrets_kv_id
  tenant_id       = data.azurerm_client_config.current.tenant_id
  object_id       = var.aks_sp_objid

  key_permissions         = [ "get", ]
  secret_permissions      = [ "get", ]
  certificate_permissions = [ "get", ]
}

#   / Reader + Network Contributor on the AKS networking RG
#     => Required for AKS Ingress to use preset Public IPs
data azurerm_resource_group aks_net_rg {
  name      = lower("rg-${local.shortl_cluster_location}-${var.subs_nickname}-aks-networking")
}
resource azurerm_role_assignment akssp_reader_aksnetrg {
  scope                   = data.azurerm_resource_group.aks_net_rg.id
  role_definition_name    = "Reader"
  principal_id            = var.aks_sp_objid
}
resource azurerm_role_assignment akssp_netcontributor_aknetsrg {
  scope                   = data.azurerm_resource_group.aks_net_rg.id
  role_definition_name    = "Network Contributor"
  principal_id            = var.aks_sp_objid
}
#*/

#--------------------------------------------------------------
#   Peer AKS VNet to the Hub VNet
#--------------------------------------------------------------
data azurerm_virtual_network hub_vnet {
  name                  = var.hub_vnet_name
  resource_group_name   = var.hub_rg_name
}
resource azurerm_virtual_network_peering "aks-to-hub" {
  name                            = lower("peering-to-hubvnet")
  resource_group_name             = azurerm_virtual_network.aks_vnet.resource_group_name
  virtual_network_name            = azurerm_virtual_network.aks_vnet.name
  remote_virtual_network_id       = data.azurerm_virtual_network.hub_vnet.id
  allow_virtual_network_access    = true
  allow_forwarded_traffic         = true
  allow_gateway_transit           = false
  use_remote_gateways             = var.hub_vnet_deploy_vnetgw == "true" ? true : false
}
resource azurerm_virtual_network_peering "hub-to-aks" {
  name                            = lower("peering-to-${replace("${azurerm_virtual_network.aks_vnet.name}","-", "")}")
  resource_group_name             = data.azurerm_virtual_network.hub_vnet.resource_group_name
  virtual_network_name            = data.azurerm_virtual_network.hub_vnet.name
  remote_virtual_network_id       = azurerm_virtual_network.aks_vnet.id
  allow_virtual_network_access    = true
  allow_forwarded_traffic         = true
  allow_gateway_transit           = true
  use_remote_gateways             = false
}
#**/

/*
#--------------------------------------------------------------
#   Private AKS Cluster DNS Zone linking
#--------------------------------------------------------------
#   ===  Connect the Private AKS Link to Hub VNet for DNS resolution (if aks_enable_privatelink == true)
resource azurerm_private_dns_zone_virtual_network_link "privaks_dnslink" {
  count                   = var.enable_privcluster ? 1 : 0

  name                    = "PrivateAksDns-To-HubVNet-Link"
  resource_group_name     = azurerm_kubernetes_cluster.aks_cluster.node_resource_group
  private_dns_zone_name   = "${split(".", azurerm_kubernetes_cluster.aks_cluster.private_fqdn)[1]}.privatelink.${azurerm_kubernetes_cluster.aks_cluster.location}.azmk8s.io"
  virtual_network_id      = data.azurerm_virtual_network.hub_vnet.id
}

#--------------------------------------------------------------
#   AKS Cluster Linking to Azure Firewall
#--------------------------------------------------------------
#   ===  Azure Firewall connection (if hub_vnet_deploy_azfw == true)
data azurerm_firewall hub_azfw {
  count               = var.hub_vnet_deploy_azfw ? 1 : 0

  name                = "${var.subs_nickname}-${var.hub_vnet_base_name}-AzFirewall${local.shortd_sharedsvc_location}"
  resource_group_name = data.azurerm_virtual_network.hub_vnet.resource_group_name
}
resource azurerm_route_table egress_udr {
  count                           = var.hub_vnet_deploy_azfw ? 1 : 0

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
  count           = var.hub_vnet_deploy_azfw ? 1 : 0

  subnet_id       = azurerm_subnet.aks_nodepool_subnet.id
  route_table_id  = azurerm_route_table.egress_udr[0].id
}
#   ===  Allow AKS NodePool to talk to AKS master
resource azurerm_firewall_application_rule_collection Allow_Nodes_To_AKSMaster {
  count               = var.hub_vnet_deploy_azfw ? 1 : 0

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