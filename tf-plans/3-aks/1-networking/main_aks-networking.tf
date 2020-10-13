# Description   : This Terraform creates an Network resources for AKS
#                 It deploys:
#                   - 1 AKS Networking Resource Group,
#                   - 1 Level 1 Traffic Manager Priority Routing
#                   - 4 Public IPs => 2 per canadian regions
#

# Folder/File   : /tf-plans/3-aks/1-networking/main_aks-networking.tf
# Terraform     : 0.13.+
# Providers     : azurerm 2.+
# Plugins       : none
# Modules       : none
#
# Created on    : 2020-07-18
# Created by    : Emmanuel
# Last Modified : 2020-09-15
# Last Modif by : Emmanuel
# Modif desc.   : Factored common plans' blocks: terraform, provider azurerm, locals


#--------------------------------------------------------------
#   Plan's Locals
#--------------------------------------------------------------
module main_shortloc {
  source    = "../../../../modules/shortloc"
  location  = var.main_location
}
locals {
  # Plan Tag value
  tf_plan   = "/tf-plans/3-aks/1-networking/main_aks-networking.tf"

  # Location1 short suffixes for AKS Networking
  shortl_aksnet_location1  = module.aksnet1_shortloc.code

  # Location2 short suffixes for AKS Networking
  shortl_aksnet_location2  = module.aksnet2_shortloc.code
}
module aksnet1_shortloc {
  source    = "../../../../modules/shortloc"
  location  = var.aksnet_location1
}
module aksnet2_shortloc {
  source    = "../../../../modules/shortloc"
  location  = var.aksnet_location2
}

#--------------------------------------------------------------
#   Data collection of required resources (KV & ACR)
#--------------------------------------------------------------
# data azurerm_key_vault kv_to_use {
#   name                = lower("kv-${local.shortl_main_location}-${var.subs_nickname}-${var.sharedsvc_kv_name}")
#   resource_group_name = lower("rg-${local.shortl_main_location}-${var.subs_nickname}-${var.sharedsvc_rg_name}")
# }
# data azurerm_container_registry acr_to_use {
#   name                = lower("acr${local.shortl_main_location}${var.subs_nickname}")
#   resource_group_name = lower("rg-${local.shortl_main_location}-${var.subs_nickname}-${var.sharedsvc_rg_name}")
# }
# #   / Log Analytics Workspace
# data azurerm_log_analytics_workspace hub_laws {
#   name                = lower("log-cac-${var.subs_nickname}-${var.sharedsvc_laws_name}")
#   resource_group_name = lower("rg-${local.shortl_main_location}-${var.subs_nickname}-${var.sharedsvc_rg_name}")
# }

#--------------------------------------------------------------
#   AKS Networking / Location 1 (Main = has the Level 1 Traffic Manager)
#--------------------------------------------------------------
#   / Location 1 Resource Group
resource azurerm_resource_group loc1_aksnet_rg {
  name        = lower("rg-${local.shortl_aksnet_location1}-${var.subs_nickname}-aks-networking")
  location    = var.aksnet_location1

  tags = local.base_tags
  lifecycle { ignore_changes = [tags["BuiltOn"]] }
}
#   / Azure Traffic Manager Level 1 (Priority)
resource azurerm_traffic_manager_profile level1_atf_prof {
  name                   = "atf-${local.shortl_aksnet_location1}-${var.subs_nickname}-level1"
  resource_group_name    = azurerm_resource_group.loc1_aksnet_rg.name
  traffic_routing_method = "Priority"

  dns_config {
    relative_name = var.atfmgr_level1_dns
    ttl           = 20
  }

  monitor_config {
    protocol                     = "http"
    port                         = 80
    path                         = "/healthz"
    interval_in_seconds          = 10         # = probing interval Enum: 10 | 30
    timeout_in_seconds           = 8          # = probe timeout / Range [5-10]
    tolerated_number_of_failures = 2
  }

  tags = local.base_tags
  lifecycle { ignore_changes = [tags["BuiltOn"]] }
}
#   / Location 1 Public IP 1
resource azurerm_public_ip loc1_ing1_pip {
  name                = lower("pip-${local.shortl_aksnet_location1}-${var.subs_nickname}-${var.piping1_name}")
  resource_group_name = azurerm_resource_group.loc1_aksnet_rg.name
  location            = var.aksnet_location1
  sku                 = var.pip_sku
  allocation_method   = var.pip_alloc_method
  domain_name_label   = lower("pip${var.subs_nickname}${var.piping1_name}")

  tags = local.base_tags
  lifecycle { ignore_changes = [tags["BuiltOn"]] }
}
#   / Location 1 Public IP 1 Traff Manager Endpoint
resource azurerm_traffic_manager_endpoint loc1_ing1_atf_endpoint {
  name                = azurerm_public_ip.loc1_ing1_pip.name
  resource_group_name = azurerm_resource_group.loc1_aksnet_rg.name
  profile_name        = azurerm_traffic_manager_profile.level1_atf_prof.name
  type                = "azureEndpoints"  # Enum: azureEndpoints | externalEndpoints | nestedEndpoints
  target_resource_id  = azurerm_public_ip.loc1_ing1_pip.id
  priority            = 10
  endpoint_status     = "Enabled"         # Enum: Enabled | Disabled
}

#   / Location 1 Public IP 2
resource azurerm_public_ip loc1_ing2_pip {
  name                = lower("pip-${local.shortl_aksnet_location1}-${var.subs_nickname}-${var.piping2_name}")
  resource_group_name = azurerm_resource_group.loc1_aksnet_rg.name
  location            = var.aksnet_location1
  sku                 = var.pip_sku
  allocation_method   = var.pip_alloc_method
  domain_name_label   = lower("pip${var.subs_nickname}${var.piping2_name}")

  tags = local.base_tags
  lifecycle { ignore_changes = [tags["BuiltOn"]] }
}
#   / Location 1 Public IP 2 Traff Manager Endpoint
resource azurerm_traffic_manager_endpoint loc1_ing2_atf_endpoint {
  name                = azurerm_public_ip.loc1_ing2_pip.name
  resource_group_name = azurerm_resource_group.loc1_aksnet_rg.name
  profile_name        = azurerm_traffic_manager_profile.level1_atf_prof.name
  type                = "azureEndpoints"  # Enum: azureEndpoints | externalEndpoints | nestedEndpoints
  target_resource_id  = azurerm_public_ip.loc1_ing2_pip.id
  priority            = 20
  endpoint_status     = "Enabled"         # Enum: Enabled | Disabled
}

#--------------------------------------------------------------
#   AKS Networking / Location 2 (Fall back)
#--------------------------------------------------------------
#   / Location 2 Resource Group
resource azurerm_resource_group loc2_aksnet_rg {
  name        = lower("rg-${local.shortl_aksnet_location2}-${var.subs_nickname}-aks-networking")
  location    = var.aksnet_location2

  tags = local.base_tags
  lifecycle { ignore_changes = [tags["BuiltOn"]] }
}
#   / Location 2 Public IP 1
resource azurerm_public_ip loc2_ing1_pip {
  name                = lower("pip-${local.shortl_aksnet_location2}-${var.subs_nickname}-${var.piping1_name}")
  resource_group_name = azurerm_resource_group.loc2_aksnet_rg.name
  location            = azurerm_resource_group.loc2_aksnet_rg.location
  sku                 = var.pip_sku
  allocation_method   = var.pip_alloc_method
  domain_name_label   = lower("pip${var.subs_nickname}${var.piping1_name}")

  tags = local.base_tags
  lifecycle { ignore_changes = [tags["BuiltOn"]] }
}
#   / Location 2 Public IP 1 Traff Manager Endpoint
resource azurerm_traffic_manager_endpoint loc2_ing1_atf_endpoint {
  name                = azurerm_public_ip.loc2_ing1_pip.name
  resource_group_name = azurerm_resource_group.loc1_aksnet_rg.name
  profile_name        = azurerm_traffic_manager_profile.level1_atf_prof.name
  type                = "azureEndpoints"  # Enum: azureEndpoints | externalEndpoints | nestedEndpoints
  target_resource_id  = azurerm_public_ip.loc2_ing1_pip.id
  priority            = 30
  endpoint_status     = "Enabled"         # Enum: Enabled | Disabled
}

#   / Location 2 Public IP 2
resource azurerm_public_ip loc2_ing2_pip {
  name                = lower("pip-${local.shortl_aksnet_location2}-${var.subs_nickname}-${var.piping2_name}")
  resource_group_name = azurerm_resource_group.loc2_aksnet_rg.name
  location            = azurerm_resource_group.loc2_aksnet_rg.location
  sku                 = var.pip_sku
  allocation_method   = var.pip_alloc_method
  domain_name_label   = lower("pip${var.subs_nickname}${var.piping2_name}")

  tags = local.base_tags
  lifecycle { ignore_changes = [tags["BuiltOn"]] }
}
#   / Location 2 Public IP 2 Traff Manager Endpoint
resource azurerm_traffic_manager_endpoint loc2_ing2_atf_endpoint {
  name                = azurerm_public_ip.loc2_ing2_pip.name
  resource_group_name = azurerm_resource_group.loc1_aksnet_rg.name
  profile_name        = azurerm_traffic_manager_profile.level1_atf_prof.name
  type                = "azureEndpoints"  # Enum: azureEndpoints | externalEndpoints | nestedEndpoints
  target_resource_id  = azurerm_public_ip.loc2_ing2_pip.id
  priority            = 40
  endpoint_status     = "Enabled"         # Enum: Enabled | Disabled
}

#--------------------------------------------------------------
#   AKS Networking / AzFw AKS Rules (conditional)
#--------------------------------------------------------------
#   / Hub networking Resource Group
data azurerm_resource_group hub_vnet_rg {
  name        = lower("rg-${local.shortl_main_location}-${var.subs_nickname}-${var.hub_vnet_base_name}")
}
#   / Get Firewall in the Hub Networking RG
data azurerm_resources azfw_in_hub_netowkring_rg {
  resource_group_name = data.azurerm_resource_group.hub_vnet_rg.name
  type                = "Microsoft.Network/azureFirewalls"
}

#   / Az Firewall AKS Global Network required
resource azurerm_firewall_network_rule_collection Allow_AksUdp_Out {
  count               = var.hub_vnet_deploy_azfw ? 1 : 0

  # Required Network Rules as per https://docs.microsoft.com/en-us/azure/aks/limit-egress-traffic#azure-global-required-network-rules
  name                = "NetworkRuleColl-Allow-AksGlobalRequiredNetwork-Out"
  azure_firewall_name = data.azurerm_resources.azfw_in_hub_netowkring_rg.resources[0].name
  resource_group_name = data.azurerm_resource_group.hub_vnet_rg.name
  priority            = 200
  action              = "Allow"

  rule {
    name              = "Allow_Udp123_to_UbuntuNTPServers"
    source_addresses  = [
      "*" ,
      ]
    destination_ports = [
      "123",
    ]
    destination_addresses = [ # ntp.ubuntu.com:123
      # "ntp.ubuntu.com", # To use when DNS preview is Enabled
      "216.55.208.22",
      "162.159.200.1",
      "91.189.94.4",
      "208.81.1.244",
      "216.232.132.31",
      "216.197.156.83",
      "209.115.181.108",
    ]
    protocols = [
      "UDP",
    ]
  }
  rule {
    name              = "Allow_Udp1194_to_AzureCloud"
    source_addresses  = [
      "*" ,
      ]
    destination_ports = [
      "1194",
    ]
    destination_addresses = [ # ServiceTag
      "AzureCloud.canadacentral",
      "AzureCloud.canadaeast",
      "AzureCloud.eastus",
    ]
    protocols = [
      "UDP",
    ]
  }
  rule {
    name              = "Allow_Tcp9000_to_AzureCloud"
    source_addresses  = [
      "*" ,
      ]
    destination_ports = [
      "9000",
    ]
    destination_addresses = [ # ServiceTag
      "AzureCloud.canadacentral",
      "AzureCloud.canadaeast",
      "AzureCloud.eastus",
    ]
    protocols = [
      "TCP",
    ]
  }
}
#   / Az Firewall AKS Global FQDNs required
resource azurerm_firewall_application_rule_collection Allow_AksGlobalFqdns_Out {
  count               = var.hub_vnet_deploy_azfw ? 1 : 0

  # Required FQDNS as per https://docs.microsoft.com/en-us/azure/aks/limit-egress-traffic#azure-global-required-fqdn--application-rules
  name                = "AppRuleColl-Allow-AksGlobalRequiredFqdns-Out"
  azure_firewall_name = data.azurerm_resources.azfw_in_hub_netowkring_rg.resources[0].name
  resource_group_name = data.azurerm_resource_group.hub_vnet_rg.name
  priority            = 220
  action              = "Allow"

  rule {
    name              = "Allow_Http80Https443_to_AksGlobalRequiredFqdns"
    source_addresses  = [ "*" , ]
    target_fqdns      = [
                          "*.hcp.canadacentral.azmk8s.io",
                          "*.hcp.canadaeast.azmk8s.io",
                          "mcr.microsoft.com",
                          "*cdn.mscr.io",
                          "*.data.mcr.microsoft.com",
                          "management.azure.com",
                          "login.microsoftonline.com",
                          "packages.microsoft.com",
                          "acs-mirror.azureedge.net",
                          # Added after Fw Logs analysis:
                          "*.opinsights.azure.com",
                          "*.dc.services.visualstudio.com", # Application Insights
                          "*.monitoring.azure.com",
                        ]

    protocol {
      port = "443"
      type = "Https"
    }
    protocol {
      port = "80"
      type = "Http"
    }
  }
}
#   / Az Firewall AKS Global FQDNs required
resource azurerm_firewall_application_rule_collection Allow_AksAzureTag_Out {
  count               = var.hub_vnet_deploy_azfw ? 1 : 0

  # Required FQDNS as per https://docs.microsoft.com/en-us/azure/aks/limit-egress-traffic#azure-global-required-fqdn--application-rules
  name                = "AppRuleColl-Allow-AksAzureTag"
  azure_firewall_name = data.azurerm_resources.azfw_in_hub_netowkring_rg.resources[0].name
  resource_group_name = data.azurerm_resource_group.hub_vnet_rg.name
  priority            = 210
  action              = "Allow"

  rule {
    name              = "Allow_All_to_AksTag"
    source_addresses  = [ "*" , ]
    fqdn_tags         = [
                          "AzureKubernetesService",
                        ]
  }
}

#   / Az Firewall Container Registries for Images Pull
resource azurerm_firewall_application_rule_collection Allow_ImagesRegistries_Out {
  count               = var.hub_vnet_deploy_azfw ? 1 : 0

  name                = "AppRuleColl-Allow-ImagesRegistries-Out"
  azure_firewall_name = data.azurerm_resources.azfw_in_hub_netowkring_rg.resources[0].name
  resource_group_name = data.azurerm_resource_group.hub_vnet_rg.name
  priority            = 400
  action              = "Allow"

  rule {
    name              = "Allow_Http80Https443_to_GoogleRegistries"
    source_addresses  = [ "*" , ]
    target_fqdns      = [
                          # Google Registry + Images configuration (for ingress-nginx):
                          "k8s.gcr.io",
                          "storage.googleapis.com",
                        ]

    protocol {
      port = "443"
      type = "Https"
    }
    protocol {
      port = "80"
      type = "Http"
    }
  }

  rule {
    name              = "Allow_Http80Https443_to_DockerRegistries"
    source_addresses  = [ "*" , ]
    target_fqdns      = [
                          # Docker registry (for kured, akv2k8s):
                          "registry-1.docker.io",
                          "registry.docker.io",
                          "auth.docker.io",
                          "production.cloudflare.docker.com",
                        ]

    protocol {
      port = "443"
      type = "Https"
    }
    protocol {
      port = "80"
      type = "Http"
    }
  }

  rule {
    name              = "Allow_Http80Https443_to_QuayRegistries"
    source_addresses  = [ "*" , ]
    target_fqdns      = [
                          # Quay (for nfs-provisioner):
                          "quay.io",
                          "cdn02.quay.io",
                        ]

    protocol {
      port = "443"
      type = "Https"
    }
    protocol {
      port = "80"
      type = "Http"
    }
  }
}