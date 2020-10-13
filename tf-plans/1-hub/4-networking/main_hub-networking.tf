# Description   : This Terraform Plan creates the Hub Networking resources in Azure.
#
#                 An Azure Hub network topology with:
#                   - Networking RG:
#                     - Hub VNet,
#                     - VNetGateway (with subnet, Public IP),
#                     - Azure Firewall - Optional (with subnet, Public IP),
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
#
#
# Folder/File   : /tf-plans/1-hub/4-networking/main.tf
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
module main_shortloc {
  source    = "../../../../modules/shortloc"
  location  = var.main_location
}
locals {
  # Plan Tag value
  tf_plan   = "/tf-plans/1-hub/4-networking/main_hub-networking.tf"

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
  name        = lower("rg-${local.shortl_main_location}-${var.subs_nickname}-${var.hub_vnet_base_name}")
  location    = var.main_location

  tags = local.base_tags
  lifecycle { ignore_changes = [tags["BuiltOn"]] }
}
#   / VNet
resource azurerm_virtual_network hub_vnet {
  name                = lower("vnet-${local.shortl_main_location}-${var.subs_nickname}-${var.hub_vnet_base_name}")
  resource_group_name = azurerm_resource_group.hub_vnet_rg.name
  location            = azurerm_resource_group.hub_vnet_rg.location
  address_space       = [ var.hub_vnet_prefix ]

  tags = local.base_tags
  lifecycle { ignore_changes = [tags["BuiltOn"]] }
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
  address_prefixes        = [ replace(var.hub_vnet_prefix, "0/24", "32/27"), ] #"172.16.0.32/27"
}
#   / VPN Gateway Public IP
resource azurerm_public_ip vpngw_pip {
  count               = var.hub_vnet_deploy_vnetgw ? 1 : 0

  name                = lower("pip-${local.shortl_main_location}-${var.subs_nickname}-vgw")
  resource_group_name = azurerm_resource_group.hub_vnet_rg.name
  location            = azurerm_resource_group.hub_vnet_rg.location
  allocation_method   = "Dynamic"

  tags = local.base_tags
  lifecycle { ignore_changes = [tags["BuiltOn"]] }
}
#   / VPN Gateway P2S (Basic to use SSTP, VpnGw1 to use IKEv2/OpenVPN)
resource azurerm_virtual_network_gateway hub_vpngw {
  count               = var.hub_vnet_deploy_vnetgw ? 1 : 0

  name                = lower("vgw-${local.shortl_main_location}-${var.subs_nickname}-${var.hub_vnet_base_name}")
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
  address_prefixes        = [ replace(var.hub_vnet_prefix, "0/24", "128/26"), ]  # Hardcoded requirement: at least /26 for Azure Firewall ipconfiguration
}
#   / Azure Firewall Public IP
resource azurerm_public_ip azfw_pip {
  count               = var.hub_vnet_deploy_azfw ? 1 : 0

  name                = lower("pip-${local.shortl_main_location}-${var.subs_nickname}-azfw")
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

  name                = lower("azfw-${local.shortl_main_location}-${var.subs_nickname}-${var.hub_vnet_base_name}")
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