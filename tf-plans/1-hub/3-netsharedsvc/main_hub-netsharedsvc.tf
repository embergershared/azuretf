# Description   : This Terraform Plan creates the Hub Networking resources in Azure.
#
#                 An Azure Hub network topology with:
#                   - 1 Networking RG:
#                     - Hub VNet,
#                     - VNetGateway (with subnet, Public IP),
#                     - Azure Firewall - Optional (with subnet, Public IP),
#                   - 1 Shared Services RG with:
#                      - Key Vault (with KeyVault access policies),
#                      - ACR,
#
#               References:
#                   https://docs.microsoft.com/en-us/azure/architecture/reference-architectures/hybrid-networking/shared-services
#                   https://docs.microsoft.com/en-us/azure/architecture/reference-architectures/hybrid-networking/vpn
#
#                   https://docs.microsoft.com/en-us/azure/firewall/tutorial-firewall-deploy-portal
#
#               Notes:
#                   To Generate the VNetGateway certificates as per:
#                       https://docs.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-howto-point-to-site-resource-manager-portal#generatecert
#                   Plans were merged to allow Locked Key Vault creation + storage of self generated VPN gateway cert in the Key Vault
#
# Folder/File   : /tf-plans/1-hub/3-netsharedsvc/main.tf
# Terraform     : 0.13.+
# Providers     : azurerm 2.+
# Plugins       : none
# Modules       : none
#
# Created on    : 2020-04-11
# Created by    : Emmanuel
# Last Modified : 2020-09-11
# Last Modif by : Emmanuel
# Modif desc.   : Factored common plans' blocks: terraform, provider azurerm, locals


#--------------------------------------------------------------
#   Plan's Locals
#--------------------------------------------------------------
module main_loc {
  source    = "../../../../modules/shortloc"
  location  = var.main_location
}
module secondary_loc {
  source    = "../../../../modules/shortloc"
  location  = var.secondary_location
}
locals {
  # Plan Tag value
  tf_plan   = "/tf-plans/1-hub/3-netsharedsvc/main_hub-netsharedsvc.tf"

  # Process Cert file to fit VnetGateway requirement
  file_data         = file(var.p2s_ca_cert_file_path)
  file_lessline1    = replace(local.file_data,"-----BEGIN CERTIFICATE-----","")
  file_lesslastline = replace(local.file_lessline1,"-----END CERTIFICATE-----","")
  cert_data         = chomp(local.file_lesslastline)
  split_cert_path   = split("\\", var.p2s_ca_cert_file_path)
  cert_name         = local.split_cert_path[length(local.split_cert_path)-1]
}

#--------------------------------------------------------------
#   Data collection of required resources
#--------------------------------------------------------------


#--------------------------------------------------------------
#   ===  Hub Networking  ===
#--------------------------------------------------------------
#   / Resource Group
resource azurerm_resource_group hub_vnet_rg {
  name        = lower("rg-${module.main_loc.code}-${var.subs_nickname}-${var.hub_vnet_base_name}")
  location    = module.main_loc.location

  tags = local.base_tags
  lifecycle { ignore_changes = [tags["BuiltOn"]] }
}
#   / VNet
resource azurerm_virtual_network hub_vnet {
  name                = lower("vnet-${module.main_loc.code}-${var.subs_nickname}-${var.hub_vnet_base_name}")
  resource_group_name = azurerm_resource_group.hub_vnet_rg.name
  location            = azurerm_resource_group.hub_vnet_rg.location
  address_space       = [ var.hub_vnet_prefix ]                                 # 172.16.1.0/24 => 172.16.1.0 > 172.16.1.255

  tags = local.base_tags
  lifecycle { ignore_changes = [tags["BuiltOn"]] }
}
#   / VMs' Subnet
resource azurerm_subnet jumpboxes_subnet {
  name                    = "snet-jumpboxes"
  resource_group_name     = azurerm_resource_group.hub_vnet_rg.name
  virtual_network_name    = azurerm_virtual_network.hub_vnet.name
  address_prefixes        = [ replace(var.hub_vnet_prefix, "0/24", "0/27"), ]
  service_endpoints       = [ "Microsoft.Storage", "Microsoft.KeyVault", "Microsoft.Sql" ]
  enforce_private_link_endpoint_network_policies  = false
  enforce_private_link_service_network_policies   = false
}

#--------------------------------------------------------------
#   Hub Networking / VNet Gateway
#--------------------------------------------------------------
#   / VNet Gateway Subnet 
resource azurerm_subnet vpngw_subnet {
  count                   = var.hub_vnet_deploy_vnetgw ? 1 : 0

  name                    = "GatewaySubnet"         # Hardcoded requirement for VNetGateway ipconfiguration
  resource_group_name     = azurerm_resource_group.hub_vnet_rg.name
  virtual_network_name    = azurerm_virtual_network.hub_vnet.name
  address_prefixes        = [ replace(var.hub_vnet_prefix, "0/24", "32/27"), ]    #"172.16.1.32/27" => 172.16.1.32 > 172.16.1.63
}
#   / VPN Gateway Public IP
resource azurerm_public_ip vpngw_pip {
  count               = var.hub_vnet_deploy_vnetgw ? 1 : 0

  name                = lower("pip-${module.main_loc.code}-${var.subs_nickname}-vgw")
  resource_group_name = azurerm_resource_group.hub_vnet_rg.name
  location            = azurerm_resource_group.hub_vnet_rg.location
  allocation_method   = "Dynamic"

  tags = local.base_tags
  lifecycle { ignore_changes = [tags["BuiltOn"]] }
}
#   / VPN Gateway P2S (Basic to use SSTP, VpnGw1 to use IKEv2/OpenVPN)
resource azurerm_virtual_network_gateway hub_vpngw {
  count               = var.hub_vnet_deploy_vnetgw ? 1 : 0

  name                = lower("vgw-${module.main_loc.code}-${var.subs_nickname}-${var.hub_vnet_base_name}")
  resource_group_name = azurerm_resource_group.hub_vnet_rg.name
  location            = azurerm_resource_group.hub_vnet_rg.location
  
  type            = "VPN"
  vpn_type        = "RouteBased"
  active_active   = false
  enable_bgp      = false
  sku             = "Basic"  # Enum: Basic | VpnGw1
  generation      = "Generation1"

  ip_configuration {
    name                          = "VPNGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.vpngw_pip[0].id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.vpngw_subnet[0].id
  }

  vpn_client_configuration {
    address_space = [ var.vpn_clients_address_space ]

    vpn_client_protocols = [
      "SSTP",
      # "IkeV2",
      # "OpenVPN",
    ]

    root_certificate {
      name              = local.cert_name
      public_cert_data  = local.cert_data
    }
  }

  tags = local.base_tags
  lifecycle { ignore_changes = [tags["BuiltOn"]] }
}

#--------------------------------------------------------------
#   Hub Networking / Azure Firewall
#--------------------------------------------------------------
#   / AzureFirewall Subnet
resource azurerm_subnet azfw_subnet {
  count                   = var.hub_vnet_deploy_azfw ? 1 : 0

  name                    = "AzureFirewallSubnet"                               # Hardcoded requirement for Azure Firewall ipconfiguration
  resource_group_name     = azurerm_resource_group.hub_vnet_rg.name
  virtual_network_name    = azurerm_virtual_network.hub_vnet.name
  address_prefixes        = [ replace(var.hub_vnet_prefix, "0/24", "128/26"), ]  # Hardcoded requirement: at least /26 for Azure Firewall ipconfiguration: 172.16.1.128/26 => 172.16.1.128 > 172.16.1.191
}
#   / Azure Firewall Public IP
resource azurerm_public_ip azfw_pip {
  count               = var.hub_vnet_deploy_azfw ? 1 : 0

  name                = lower("pip-${module.main_loc.code}-${var.subs_nickname}-azfw")
  resource_group_name = azurerm_resource_group.hub_vnet_rg.name
  location            = azurerm_resource_group.hub_vnet_rg.location
  sku                 = "Standard"
  allocation_method   = "Static"

  tags = local.base_tags
  lifecycle { ignore_changes = [tags["BuiltOn"]] }
}
#   /  Azure Firewall
resource azurerm_firewall hub_azfw {
  count               = var.hub_vnet_deploy_azfw ? 1 : 0

  name                = lower("azfw-${module.main_loc.code}-${var.subs_nickname}-${var.hub_vnet_base_name}")
  location            = azurerm_resource_group.hub_vnet_rg.location
  resource_group_name = azurerm_resource_group.hub_vnet_rg.name
  ip_configuration {
    name                 = "AzFwPublicIpConfig"
    subnet_id            = azurerm_subnet.azfw_subnet[0].id
    public_ip_address_id = azurerm_public_ip.azfw_pip[0].id
  }
  tags = local.base_tags
  lifecycle { ignore_changes = [tags["BuiltOn"]] }
}


#--------------------------------------------------------------
#   ===  Hub Shared Services  ===
#--------------------------------------------------------------
#   / Resource Group
resource azurerm_resource_group sharedsvc_rg {
  name        = lower("rg-${module.main_loc.code}-${var.subs_nickname}-${var.sharedsvc_rg_name}")
  location    = module.main_loc.location

  tags = local.base_tags
  lifecycle { ignore_changes = [tags["BuiltOn"]] }
}

#--------------------------------------------------------------
#   Hub Shared Services / Azure Key Vault
#--------------------------------------------------------------
#   / Azure Key Vault Main
module kv_main {
  source                        = "../../../../modules/keyvault"

  name                          = lower("kv-${module.main_loc.code}-${var.subs_nickname}-${var.sharedsvc_kv_suffix}")
  resource_group_name           = azurerm_resource_group.sharedsvc_rg.name
  location                      = azurerm_resource_group.sharedsvc_rg.location
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  public_internet_ips_to_allow  = var.public_internet_ips_to_allow
  virtual_network_subnet_ids    = [ azurerm_subnet.jumpboxes_subnet.id ]
  sharedsvc_kv_owners           = var.sharedsvc_kv_owners
  sharedsvc_kv_fullaccess       = var.sharedsvc_kv_fullaccess
  tf_sp_objid                   = data.azurerm_client_config.current.object_id
  base_tags                     = local.base_tags
}

#   / Azure Key Vault Secondary (required for CMK keys that must be in same location as their KV)
module kv_secondary {
  source                        = "../../../../modules/keyvault"

  name                          = lower("kv-${module.secondary_loc.code}-${var.subs_nickname}-${var.sharedsvc_kv_suffix}")
  resource_group_name           = azurerm_resource_group.sharedsvc_rg.name
  location                      = module.secondary_loc.location
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  public_internet_ips_to_allow  = var.public_internet_ips_to_allow
  virtual_network_subnet_ids    = [ azurerm_subnet.jumpboxes_subnet.id ]
  sharedsvc_kv_owners           = var.sharedsvc_kv_owners
  sharedsvc_kv_fullaccess       = var.sharedsvc_kv_fullaccess
  tf_sp_objid                   = data.azurerm_client_config.current.object_id
  base_tags                     = local.base_tags
}

#--------------------------------------------------------------
#   Hub Shared Services / Azure Container Registry
#--------------------------------------------------------------
#   / Azure Container Registry
resource azurerm_container_registry sharedsvc_acr {
  count                   = var.sharedsvc_acr_deploy ? 1 : 0

  name                    = lower("acr${module.main_loc.code}${var.subs_nickname}${var.sharedsvc_acr_suffix}") # 5-50 alphanumeric characters
  resource_group_name     = azurerm_resource_group.sharedsvc_rg.name
  location                = azurerm_resource_group.sharedsvc_rg.location
  sku                     = "Basic"
  admin_enabled           = false
  
  tags = local.base_tags
  lifecycle { ignore_changes = [tags["BuiltOn"]] }
}