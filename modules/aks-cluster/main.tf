# Description   : This Terraform module creates an AKS Cluster
#                 It deploys:
#                   - 1 AKS Resource Group,
#                   - 1 VNet / 2 subnets:
#                     - 1 Subnet for NodePool(s),
#                   - 1 AKS cluster with Service Principal,
#                   - Required permissions for the AKS Cluster's Service Principal or Managed Identity,
#                   - VNet Peering with a Hub VNet,
#                   - Private Endpoint link if Private Cluster,
#                   - Azure Firewall rules if Azure Firewall.


# Folder/File   : /modules/aks/main.tf
# Terraform     : >= 0.13
# Providers     : azurerm, kubernetes,
# Plugins       : none
# Modules       : none
#
# Created on    : 2020-07-16
# Created by    : Emmanuel Bergerat
# Last Modified : 2020-09-19
# Last Modif by : Emmanuel Bergerat
# Modification  : Create dynamic to use either {identity} or {service_principal}

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
  module_tags = merge(var.base_tags, "${map(
    "TfModule", "/modules/aks-cluster/main.tf",
    "KubeVersion", "${var.k8s_version}",
  )}")

  # Now
  now                   = timestamp() # in UTC
  nowUTCFormatted       = "${formatdate("YYYY-MM-DD", local.now)}T${formatdate("hh:mm:ss", local.now)}Z" # "2029-01-01T01:01:01Z"
}
module aks_loc {
  source    = "../shortloc"
  location  = var.cluster_location
}
provider random {
  version = "~> 2.2"
}
provider tls {
  version = "~> 2.1"
}

#--------------------------------------------------------------
#   2.: Modules Dependencies (In & Out)
#--------------------------------------------------------------
provider "null" {
  version = "~> 2.1"
}
resource null_resource dependency_modules {
  provisioner "local-exec" {
    command = "echo ${length(var.dependencies)}"
  }
}
resource null_resource aks_module_completion {
  depends_on = [
    azurerm_kubernetes_cluster.aks_cluster,
    #azurerm_role_assignment.aks_principals_reader_acr,
    azurerm_role_assignment.aks_principals_contributor_aksrg,
    azurerm_key_vault_access_policy.aks_principals_accessget_kv,
    #azurerm_role_assignment.aks_principals_reader_aksnetrg,
    azurerm_role_assignment.aks_principals_contributor_aksnetrg,
    azurerm_virtual_network_peering.hub_to_aks,
    azurerm_virtual_network_peering.aks_to_hub,
  ]
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
  name        = lower("rg-${module.aks_loc.code}-${var.subs_nickname}-aks-${var.cluster_name}")
  location    = module.aks_loc.location

  tags = local.module_tags
  lifecycle { ignore_changes = [tags["BuiltOn"]] }
}

#--------------------------------------------------------------
#   AKS Networking
#--------------------------------------------------------------
resource azurerm_virtual_network aks_vnet {
  name                    = lower("vnet-${module.aks_loc.code}-${var.subs_nickname}-aks-${var.cluster_name}")
  location                = azurerm_resource_group.aks_rg.location
  resource_group_name     = azurerm_resource_group.aks_rg.name
  address_space           = [ var.aks_vnet_cidr ]

  tags = local.module_tags
  lifecycle { ignore_changes = [tags["BuiltOn"]] }
}
resource azurerm_subnet aks_nodespods_subnet {
  name                    = "snet-nodespods"
  resource_group_name     = azurerm_resource_group.aks_rg.name
  virtual_network_name    = azurerm_virtual_network.aks_vnet.name
  enforce_private_link_endpoint_network_policies = true # Set to true to enable Private Endpoints (previous was: var.enable_privcluster)
  address_prefixes        = [ var.aks_vnet_cidr ]
  service_endpoints       = [ "Microsoft.KeyVault", "Microsoft.Sql",
                              "Microsoft.ContainerRegistry", "Microsoft.Storage" ]
}

#--------------------------------------------------------------
#   AKS Nodes ssh key
#--------------------------------------------------------------
#   / Generate ssh Private key
resource tls_private_key ssh_key {
  algorithm = "RSA"
  rsa_bits  = 2048
}
#   / Store Private Key in Key Vault
resource azurerm_key_vault_secret ssh_privpem_secret {
  name            = lower("aks-${module.aks_loc.code}-${var.subs_nickname}-${var.cluster_name}-ssh-privkey-pem")
  key_vault_id    = var.secrets_kv_id
  not_before_date = local.nowUTCFormatted

  value           = tls_private_key.ssh_key.private_key_pem

  tags = merge(local.module_tags, "${map(
    "file-encoding", "utf-8",
  )}")
  lifecycle { ignore_changes  = [ tags["BuiltOn"], ] }
}

#--------------------------------------------------------------
#   AKS Nodes Customer Managed Key (CMK encryption)
#--------------------------------------------------------------
#   / Generate disk encryption key
resource azurerm_key_vault_key cmk_key {
  name         = lower("aks-${module.aks_loc.code}-${var.subs_nickname}-${var.cluster_name}-cmk-privkey")
  key_vault_id = var.secrets_kv_id
  key_type     = "RSA"
  key_size     = 2048

  key_opts = [
    "decrypt", "encrypt", "sign",
    "unwrapKey", "verify", "wrapKey"
  ]

  depends_on = [null_resource.dependency_modules]
}

#   / Create Disk Encryption Set for AKS
resource azurerm_disk_encryption_set cmk_des {
  name                = lower("des-${module.aks_loc.code}-${var.subs_nickname}-${var.cluster_name}")
  location            = azurerm_resource_group.aks_rg.location
  resource_group_name = azurerm_resource_group.aks_rg.name
  key_vault_key_id    = azurerm_key_vault_key.cmk_key.id

  identity {
    type = "SystemAssigned"
  }

  tags = local.module_tags
}

#   / Add Key Vault Access Policy for the Disk Encryption Set MSI
resource azurerm_key_vault_access_policy cmk {
  key_vault_id = var.secrets_kv_id

  tenant_id = azurerm_disk_encryption_set.cmk_des.identity.0.tenant_id
  object_id = azurerm_disk_encryption_set.cmk_des.identity.0.principal_id

  key_permissions    = ["get", "decrypt", "encrypt", "sign", "unwrapKey", "verify", "wrapKey"]
  secret_permissions = ["get"]
}

#--------------------------------------------------------------
#   AKS Cluster
#--------------------------------------------------------------
# Ref: https://docs.microsoft.com/en-us/cli/azure/aks?view=azure-cli-latest#az-aks-create
locals {
  availzones  = lookup({
    1 = ["1"],
    2 = ["1","2"],
    3 = ["1","2","3"],
    },
    var.default_np_availzonescount, null)
}

resource azurerm_kubernetes_cluster aks_cluster {
  depends_on                  = [ tls_private_key.ssh_key ]

  name                        = lower("aks-${module.aks_loc.code}-${var.subs_nickname}-${var.cluster_name}")
  location                    = azurerm_resource_group.aks_rg.location
  dns_prefix                  = replace(lower("aks-${module.aks_loc.code}-${var.subs_nickname}-${var.cluster_name}"), "-", "")
  resource_group_name         = azurerm_resource_group.aks_rg.name
  kubernetes_version          = var.k8s_version        # check with: az aks get-versions --location canadacentral --output table
  node_resource_group         = "${azurerm_resource_group.aks_rg.name}-managed"
  enable_pod_security_policy  = var.enable_podsecurpol           # Needs the preview feature enabled: "Microsoft.ContainerService/PodSecurityPolicyPreview": az feature register --name PodSecurityPolicyPreview --namespace Microsoft.ContainerService
  private_cluster_enabled     = var.enable_privcluster
  api_server_authorized_ip_ranges = var.authorized_ips == null ? null : [ var.authorized_ips ]
  disk_encryption_set_id      = azurerm_disk_encryption_set.cmk_des.id

  dynamic service_principal {
    for_each = var.aks_sp_appid != null ? [true] : []
    content {
      client_id     = var.aks_sp_appid
      client_secret = var.aks_sp_appsecret
    }
  }

  dynamic identity {
    for_each = var.aks_sp_appid != null ? [] : [true]
    content {
      type = "SystemAssigned"
    }
  }

  role_based_access_control {
    enabled = "true"
    dynamic azure_active_directory {
      for_each = var.admin_group_object_ids != null ? [true] : []
      content {
        managed = true
        admin_group_object_ids = var.admin_group_object_ids
        # server_app_id       = data.azurerm_key_vault_secret.aad_server_id.value
        # server_app_secret   = data.azurerm_key_vault_secret.aad_server_secret.value
        # client_app_id       = data.azurerm_key_vault_secret.aad_client_id.value
      }
    }
  }

  default_node_pool {
    vnet_subnet_id        = azurerm_subnet.aks_nodespods_subnet.id

    name                  = var.default_np_name
    vm_size               = var.default_np_vmsize
    os_disk_size_gb       = var.default_np_osdisksize
    type                  = var.default_np_type
    enable_node_public_ip = var.default_np_enablenodepubip

    availability_zones    = local.availzones   # https://docs.microsoft.com/en-us/azure/aks/availability-zones

    enable_auto_scaling   = var.default_np_enableautoscale
    node_count            = var.default_np_nodecount
    max_count             = var.default_np_max_count
    min_count             = var.default_np_min_count

    max_pods              = var.default_np_maxpods          # The network used is azure (cni): 30 is default, max is 250 | kubenet: 110

    #tags = local.module_tags
  }

  dynamic auto_scaler_profile {
    for_each = var.default_np_enableautoscale ? [true] : []
    content {
      balance_similar_node_groups       = var.balance_similar_node_groups
      max_graceful_termination_sec      = var.max_graceful_termination_sec
      scale_down_delay_after_add        = var.scale_down_delay_after_add
      scale_down_delay_after_delete     = var.scale_down_delay_after_delete
      scale_down_delay_after_failure    = var.scale_down_delay_after_failure
      scan_interval                     = var.scan_interval
      scale_down_unneeded               = var.scale_down_unneeded
      scale_down_unready                = var.scale_down_unready
      scale_down_utilization_threshold  = var.scale_down_utilization_threshold
    }
  }

  linux_profile {
    admin_username = var.linx_admin_user
    ssh_key {
      key_data = tls_private_key.ssh_key.public_key_openssh
    }
  }

  windows_profile {
    admin_username = var.win_admin_username
    admin_password = var.win_admin_password
  }

  network_profile {
    network_plugin      = var.network_plugin
    network_policy      = var.network_policy
    outbound_type       = var.outbound_type
    load_balancer_sku   = var.load_balancer_sku
    dns_service_ip      = var.dns_service_ip
    service_cidr        = var.service_cidr
    docker_bridge_cidr  = var.docker_bridge_cidr
  }

  addon_profile {
    dynamic oms_agent {
      for_each = var.enable_omsagent ? [true] : []
      content {
        enabled                     = true
        log_analytics_workspace_id  = var.laws_id
      }
    }
    http_application_routing {
      enabled = var.enable_devspaces
      # When Enabled, it creates a dedicated DNS zone in the Managed RG + 1 additional Public IP (for the ingress-controller)
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
  lifecycle {
    ignore_changes = [
      tags["BuiltOn"],
      linux_profile[0].ssh_key[0].key_data,
      addon_profile[0].oms_agent[0].log_analytics_workspace_id, # Looks like a bug in the azurerm provider: it wants to replace it all the time
      ]
    }
}

#--------------------------------------------------------------
#   Generate AKS Cluster Principal(s) list
#--------------------------------------------------------------
locals {
  aks_principals = var.aks_sp_appid != null ? [ var.aks_sp_objid ] : [ azurerm_kubernetes_cluster.aks_cluster.kubelet_identity[0].object_id, azurerm_kubernetes_cluster.aks_cluster.identity[0].principal_id ]

  # aks_principals = var.aks_sp_appid != null ? [ var.aks_sp_objid ] : concat(flatten([
  #   # Process Managed Identities
  #   for x in azurerm_kubernetes_cluster.aks_cluster.identity :
  #     x.principal_id
  #   ]),
  # [ azurerm_kubernetes_cluster.aks_cluster.kubelet_identity[0].object_id ]
  # )

  # aks_agentpool_ids = flatten([
  #   for x in azurerm_kubernetes_cluster.this :
  #   [
  #     # Agentpool MSI
  #     for z in x.kubelet_identity :
  #     z.object_id if z.object_id != ""
  #   ] if length(keys(azurerm_kubernetes_cluster.this)) > 0
  # ])
}

resource null_resource display_principal1 {
  depends_on              = [ azurerm_kubernetes_cluster.aks_cluster ]

  provisioner "local-exec" {
    command = "echo ${local.aks_principals[0]}"
    interpreter = ["PowerShell", "-Command"]
  }
}
resource null_resource display_principal2 {
  depends_on              = [ azurerm_kubernetes_cluster.aks_cluster ]
  count                   = length(local.aks_principals) == 2 ? 1 : 0

  provisioner "local-exec" {
    command = "echo ${local.aks_principals[1]}"
    interpreter = ["PowerShell", "-Command"]
  }
}

#--------------------------------------------------------------
#   Required permissions for the AKS Cluster Principal(s)
#--------------------------------------------------------------
# #   / Reader on the ACR
# #     => Required to pull images
# resource azurerm_role_assignment aks_principals_reader_acr {
#   depends_on              = [ azurerm_kubernetes_cluster.aks_cluster ]
#   count                   = length(local.aks_principals)

#   scope                   = var.acr_id
#   role_definition_name    = "Reader"
#   principal_id            = element(local.aks_principals, count.index)
# }

#   / Contributor on the AKS Cluster RG
#     => Required for AKS to:
#     - use Azure Static disks and mount them
#     - deploy an Internal Load Balancer (Network Contributor is enough for this one)
resource azurerm_role_assignment aks_principals_contributor_aksrg {
  depends_on              = [ azurerm_kubernetes_cluster.aks_cluster ]
  count                   = length(local.aks_principals)

  scope                   = azurerm_resource_group.aks_rg.id
  role_definition_name    = "Contributor"
  principal_id            = element(local.aks_principals, count.index)
}

#   / Access Policy "Get" to Key Vault
#     => Required for k8s & pods to pull secrets
resource azurerm_key_vault_access_policy aks_principals_accessget_kv {
  depends_on              = [ azurerm_kubernetes_cluster.aks_cluster ]
  count                   = length(local.aks_principals)

  key_vault_id            = var.secrets_kv_id
  tenant_id               = data.azurerm_client_config.current.tenant_id
  object_id               = element(local.aks_principals, count.index)

  key_permissions         = [ "get", ]
  secret_permissions      = [ "get", ]
  certificate_permissions = [ "get", ]
}

#   / Reader + Network Contributor OR Contributor on the aks-networking RG
#     => Required for AKS Ingress to use precreated Public IPs
data azurerm_resource_group aks_networking_rg {
  name      = lower("rg-${module.aks_loc.code}-${var.subs_nickname}-aks-networking")
}
resource azurerm_role_assignment aks_principals_contributor_aksnetrg {
  depends_on              = [ azurerm_kubernetes_cluster.aks_cluster ]
  count                   = length(local.aks_principals)

  scope                   = data.azurerm_resource_group.aks_networking_rg.id
  role_definition_name    = "Contributor"
  principal_id            = element(local.aks_principals, count.index)
}
# resource azurerm_role_assignment aks_principals_reader_aksnetrg {
#   depends_on              = [ azurerm_kubernetes_cluster.aks_cluster ]
#   count                   = length(local.aks_principals)

#   scope                   = data.azurerm_resource_group.aks_networking_rg.id
#   role_definition_name    = "Reader"
#   principal_id            = element(local.aks_principals, count.index)
# }
#*/

#--------------------------------------------------------------
#   Peer AKS VNet to the Hub VNet
#--------------------------------------------------------------
data azurerm_virtual_network hub_vnet {
  name                  = var.hub_vnet_name
  resource_group_name   = var.hub_rg_name
}
resource azurerm_virtual_network_peering aks_to_hub {
  name                            = lower("peering-to-hubvnet")
  resource_group_name             = azurerm_virtual_network.aks_vnet.resource_group_name
  virtual_network_name            = azurerm_virtual_network.aks_vnet.name
  remote_virtual_network_id       = data.azurerm_virtual_network.hub_vnet.id
  allow_virtual_network_access    = true
  allow_forwarded_traffic         = true
  allow_gateway_transit           = false
  use_remote_gateways             = var.hub_vnet_deploy_vnetgw
}
resource azurerm_virtual_network_peering hub_to_aks {
  name                            = lower("peering-to-${replace("${azurerm_virtual_network.aks_vnet.name}","-", "")}")
  resource_group_name             = data.azurerm_virtual_network.hub_vnet.resource_group_name
  virtual_network_name            = data.azurerm_virtual_network.hub_vnet.name
  remote_virtual_network_id       = azurerm_virtual_network.aks_vnet.id
  allow_virtual_network_access    = true
  allow_forwarded_traffic         = false
  allow_gateway_transit           = true
  use_remote_gateways             = false
}
#*/

#--------------------------------------------------------------
#   Private AKS Cluster DNS Zone linking
#--------------------------------------------------------------
#   ===  Connect the Private AKS Link to Hub VNet for DNS resolution (if aks_enable_privatelink == true)
resource azurerm_private_dns_zone_virtual_network_link privaks_dnslink {
  count                   = var.enable_privcluster ? 1 : 0

  name                    = lower("${title(var.cluster_name)}PrivClusterDnsZone-link-To-HubVNet")
  resource_group_name     = azurerm_kubernetes_cluster.aks_cluster.node_resource_group
  private_dns_zone_name   = "${split(".", azurerm_kubernetes_cluster.aks_cluster.private_fqdn)[1]}.privatelink.${azurerm_kubernetes_cluster.aks_cluster.location}.azmk8s.io"
  virtual_network_id      = data.azurerm_virtual_network.hub_vnet.id

  tags = local.module_tags
  lifecycle { ignore_changes = [  tags["BuiltOn"], ] }
}

#--------------------------------------------------------------
#   AKS Cluster Linking to Azure Firewall
#--------------------------------------------------------------
#   ===  Azure Firewall connection (if hub_vnet_deploy_azfw == true)
data azurerm_firewall hub_azfw {
  count               = var.hub_vnet_deploy_azfw ? 1 : 0

  name                = var.hub_azfw_name
  resource_group_name = data.azurerm_virtual_network.hub_vnet.resource_group_name
}
data azurerm_public_ip azfw_pip {
  count               = var.hub_vnet_deploy_azfw ? 1 : 0

  name                = split("/", data.azurerm_firewall.hub_azfw[0].ip_configuration[0].public_ip_address_id)[8]
  resource_group_name = data.azurerm_virtual_network.hub_vnet.resource_group_name
}
resource azurerm_route_table egress_udr {
  count                           = var.hub_vnet_deploy_azfw ? 1 : 0

  name                            = "udr-${module.aks_loc.code}-${replace(azurerm_subnet.aks_nodespods_subnet.name, "-", "")}-egress-to-azfw"
  location                        = azurerm_virtual_network.aks_vnet.location
  resource_group_name             = azurerm_virtual_network.aks_vnet.resource_group_name
  disable_bgp_route_propagation   = false

  route {
    name                    = "egress_to_firewallInternet"
    address_prefix          = "${data.azurerm_public_ip.azfw_pip[0].ip_address}/32"
    next_hop_type           = "Internet"
  }
  route {
    name                    = "egress_to_firewall"
    address_prefix          = "0.0.0.0/0"
    next_hop_type           = "VirtualAppliance"
    next_hop_in_ip_address  = data.azurerm_firewall.hub_azfw[0].ip_configuration[0].private_ip_address
  }
}
resource azurerm_subnet_route_table_association nodesvnet_to_fw {
  count           = var.hub_vnet_deploy_azfw ? 1 : 0

  subnet_id       = azurerm_subnet.aks_nodespods_subnet.id
  route_table_id  = azurerm_route_table.egress_udr[0].id
}
#   ===  Allow AKS NodePool to talk to AKS master & svc.local
resource random_integer rule_num {
  count               = var.hub_vnet_deploy_azfw ? 1 : 0

  min = 300
  max = 399
}
resource azurerm_firewall_application_rule_collection Allow_Nodes_To_KubeApiServer {
  count               = var.hub_vnet_deploy_azfw ? 1 : 0

  name                = "AppRuleColl-Allow-AksCluster${title(var.cluster_name)}NodesSubnet-To-${title(var.cluster_name)}ClusterKubeApi"
  azure_firewall_name = data.azurerm_firewall.hub_azfw[0].name
  resource_group_name = data.azurerm_firewall.hub_azfw[0].resource_group_name
  priority            = random_integer.rule_num[0].result
  action              = "Allow"

  rule {
    name = "Allow_Https443_from_AksCluster${title(var.cluster_name)}NodesSubnet_to_${title(var.cluster_name)}ClusterKubeApi"
    source_addresses = [ azurerm_subnet.aks_nodespods_subnet.address_prefix , ]
    target_fqdns = var.enable_privcluster ? [ azurerm_kubernetes_cluster.aks_cluster.private_fqdn ] : [ azurerm_kubernetes_cluster.aks_cluster.fqdn ]
    protocol {
      port = "443"
      type = "Https"
    }
  }
}
resource azurerm_firewall_network_rule_collection Allow_Nodes_To_SvcLocal {
  count               = var.hub_vnet_deploy_azfw ? 1 : 0

  name                = "NetworkRuleColl-Allow-AksCluster${title(var.cluster_name)}NodesSubnet-To-SvcLocal"
  azure_firewall_name = data.azurerm_firewall.hub_azfw[0].name
  resource_group_name = data.azurerm_firewall.hub_azfw[0].resource_group_name
  priority            = random_integer.rule_num[0].result
  action              = "Allow"

  rule {
    name = "Allow_Tcp443_from_AksCluster${title(var.cluster_name)}NodesSubnet_to_SvcLocal"
    source_addresses = [
      azurerm_subnet.aks_nodespods_subnet.address_prefix,
      ]
    destination_ports = [
      "443",
    ]
    destination_addresses = [
      "*",
    ]
    protocols = [
      "TCP",
    ]
  }
}
#*/