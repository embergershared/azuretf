# Description   : This Terraform Plan creates the Hub Networking Private Endpoints resources in Azure.
#
#                 An Azure Hub network topology with:
#                   - Within the Hub Networking RG:
#                     - Private DNS Zones,
#                     - A Private Endpoint subnet,
#
#               References:
#
#               Notes:
#
# Folder/File   : /tf-plans/1-hub/4-privendpoints/main.tf
# Terraform     : 0.13.+
# Providers     : azurerm 2.+
# Plugins       : none
# Modules       : none
#
# Created on    : 2020-04-11
# Created by    : Emmanuel
# Last Modified : 2020-11-08
# Last Modif by : Emmanuel
# Modif desc.   : Refactored Hub resources deployment


#--------------------------------------------------------------
#   Plan's Locals
#--------------------------------------------------------------
module main_loc {
  source    = "../../../../modules/shortloc"
  location  = var.main_location
}
locals {
  # Plan Tag value
  tf_plan   = "/tf-plans/1-hub/4-privendpoints/main_hub-netsharedsvc.tf"

  # Extracting Data Sub Key Vault name from its Resource Id
  data_sub_kv_name  = split("/", data.azurerm_key_vault_secret.data_sub_kv_id.value)[8]

  # Extracting Data Sub Storage Account name from its Resource Id
  data_sub_st_name  = split("/", data.azurerm_key_vault_secret.data_sub_st_id.value)[8]
}

#--------------------------------------------------------------
#   Data collection of required resources
#--------------------------------------------------------------
#   / Hub Subscription Main Key Vault
data azurerm_key_vault hub_sub_kv {
  name                  = lower("kv-${module.main_loc.code}-${var.subs_nickname}-${var.sharedsvc_kv_suffix}")
  resource_group_name   = lower("rg-${module.main_loc.code}-${var.subs_nickname}-${var.sharedsvc_rg_name}")
}
#   / Data Subscription: Key Vault Resource Id to use
#   (SP requires "Get" access policy role in Data Sub Key Vault)
data azurerm_key_vault_secret data_sub_kv_id {
  key_vault_id  = data.azurerm_key_vault.hub_sub_kv.id
  name          =  var.data_sub_kv_id_kvsecret
}
#   / Data Subscription: Storage Account Resource Id to use
#   (Access is done using storage Key)
data azurerm_key_vault_secret data_sub_st_id {
  key_vault_id  = data.azurerm_key_vault.hub_sub_kv.id
  name          = var.data_sub_st_id_kvsecret
}
#   / Resource Group
data azurerm_resource_group hub_vnet_rg {
  name        = lower("rg-${module.main_loc.code}-${var.subs_nickname}-${var.hub_vnet_base_name}")
}
#   / VNet
data azurerm_virtual_network hub_vnet {
  name                = lower("vnet-${module.main_loc.code}-${var.subs_nickname}-${var.hub_vnet_base_name}")
  resource_group_name = data.azurerm_resource_group.hub_vnet_rg.name
}


#--------------------------------------------------------------
#   Hub Networking / Private Endpoints & DNS (zones+records)
#--------------------------------------------------------------
#   / Dedicated subnet for Private Endpoints
resource azurerm_subnet pe_subnet {
  name                    = "snet-pe"
  resource_group_name     = data.azurerm_resource_group.hub_vnet_rg.name
  virtual_network_name    = data.azurerm_virtual_network.hub_vnet.name
  address_prefixes        = [ replace(var.hub_vnet_prefix, "0/24", "192/27"), ]   #"172.16.1.192/27" => 172.16.1.192 > 172.16.1.223
  enforce_private_link_endpoint_network_policies = true                           # Set to true to enable Private Endpoints / Disable NSG
  service_endpoints       = []
}

#   / ###   PE to Key Vault in Data Subscription
#     / Create Private DNS Zones
resource azurerm_private_dns_zone vault_azure_net {
  name                = "vault.azure.net"
  resource_group_name = data.azurerm_resource_group.hub_vnet_rg.name
  tags                = local.base_tags
}
resource azurerm_private_dns_zone vaultcore_azure_net {
  name                = "vaultcore.azure.net"
  resource_group_name = data.azurerm_resource_group.hub_vnet_rg.name
  tags                = local.base_tags
}
#     / Link Key Vault Private DNS Zones to Hub VNet
resource azurerm_private_dns_zone_virtual_network_link vault_azure_net-link {
  name                  = "${azurerm_private_dns_zone.vault_azure_net.name}-to-${replace(data.azurerm_virtual_network.hub_vnet.name, "-", "_")}-link"
  resource_group_name   = data.azurerm_resource_group.hub_vnet_rg.name
  private_dns_zone_name = azurerm_private_dns_zone.vault_azure_net.name
  virtual_network_id    = data.azurerm_virtual_network.hub_vnet.id
  registration_enabled  = false
  tags                  = local.base_tags
}
resource azurerm_private_dns_zone_virtual_network_link vaultcore_azure_net-link {
  name                  = "${azurerm_private_dns_zone.vaultcore_azure_net.name}-to-${replace(data.azurerm_virtual_network.hub_vnet.name, "-", "_")}-link"
  resource_group_name   = data.azurerm_resource_group.hub_vnet_rg.name
  private_dns_zone_name = azurerm_private_dns_zone.vaultcore_azure_net.name
  virtual_network_id    = data.azurerm_virtual_network.hub_vnet.id
  registration_enabled  = false
  tags                  = local.base_tags
}
#     / Create Private Endpoint to Data Key Vault on Hub PE Subnet
resource azurerm_private_endpoint data_sub_kv_pe {
  name                = "${local.data_sub_kv_name}-pe"
  location            = data.azurerm_resource_group.hub_vnet_rg.location
  resource_group_name = data.azurerm_resource_group.hub_vnet_rg.name
  subnet_id           = azurerm_subnet.pe_subnet.id

  private_service_connection {
    name                            = "${replace(data.azurerm_virtual_network.hub_vnet.name, "-", "_")}-${replace(azurerm_subnet.pe_subnet.name, "-", "_")}-connection"
    private_connection_resource_id  = data.azurerm_key_vault_secret.data_sub_kv_id.value
    subresource_names               = ["vault"]
    is_manual_connection            = true
    request_message                 = "Please approve this connection (Author= Emmanuel)"
  }

  private_dns_zone_group {
    name                  = "default"
    private_dns_zone_ids  = [ azurerm_private_dns_zone.vaultcore_azure_net.id ]
  }

  tags                    = local.base_tags
}
#     / Create CNAME record in vault.azure.net for redirect to the Private Endpoint A record
resource azurerm_private_dns_cname_record vault_to_vaultcore_cname {
  name                  = local.data_sub_kv_name
  zone_name             = azurerm_private_dns_zone.vault_azure_net.name # vault.azure.net
  resource_group_name   = data.azurerm_resource_group.hub_vnet_rg.name
  ttl                   = 300
  record                = "${local.data_sub_kv_name}.${azurerm_private_dns_zone.vaultcore_azure_net.name}"
  tags                  = local.base_tags
}

#   / ###   PE to File shares Storage Account in Data Subscription
#     / Create Private DNS Zones
resource azurerm_private_dns_zone file_core_windows_net {
  name                = "file.core.windows.net"
  resource_group_name = data.azurerm_resource_group.hub_vnet_rg.name
  tags                = local.base_tags
}
resource azurerm_private_dns_zone privatelink_file_core_windows_net {
  name                = "privatelink.file.core.windows.net"
  resource_group_name = data.azurerm_resource_group.hub_vnet_rg.name
  tags                = local.base_tags
}
#     / Link Storage Account Private DNS Zones to Hub VNet
resource azurerm_private_dns_zone_virtual_network_link file_core_windows_net-link {
  name                  = "${azurerm_private_dns_zone.file_core_windows_net.name}-to-${replace(data.azurerm_virtual_network.hub_vnet.name, "-", "_")}-link"
  resource_group_name   = data.azurerm_resource_group.hub_vnet_rg.name
  private_dns_zone_name = azurerm_private_dns_zone.file_core_windows_net.name
  virtual_network_id    = data.azurerm_virtual_network.hub_vnet.id
  registration_enabled  = false
  tags                  = local.base_tags
}
resource azurerm_private_dns_zone_virtual_network_link privatelink_file_core_windows_net-link {
  name                  = "${azurerm_private_dns_zone.privatelink_file_core_windows_net.name}-to-${replace(data.azurerm_virtual_network.hub_vnet.name, "-", "_")}-link"
  resource_group_name   = data.azurerm_resource_group.hub_vnet_rg.name
  private_dns_zone_name = azurerm_private_dns_zone.privatelink_file_core_windows_net.name
  virtual_network_id    = data.azurerm_virtual_network.hub_vnet.id
  registration_enabled  = false
  tags                  = local.base_tags
}
#     / Create Private Endpoint to Data Storage Account on Hub PE Subnet
resource azurerm_private_endpoint data_sub_st_pe {
  name                = "${local.data_sub_st_name}-pe"
  location            = data.azurerm_resource_group.hub_vnet_rg.location
  resource_group_name = data.azurerm_resource_group.hub_vnet_rg.name
  subnet_id           = azurerm_subnet.pe_subnet.id

  private_service_connection {
    name                            = "${replace(data.azurerm_virtual_network.hub_vnet.name, "-", "_")}-${replace(azurerm_subnet.pe_subnet.name, "-", "_")}-connection"
    private_connection_resource_id  = data.azurerm_key_vault_secret.data_sub_st_id.value
    subresource_names               = ["file"]
    is_manual_connection            = true
    request_message                 = "Please approve this connection (Author= Emmanuel)"
  }

  private_dns_zone_group {
    name                  = "default"
    private_dns_zone_ids  = [ azurerm_private_dns_zone.privatelink_file_core_windows_net.id ] # "privatelink.file.core.windows.net"
  }

  tags                    = local.base_tags
}
#     / Create CNAME record in file.core.windows.net for redirect to the Private Endpoint A record in "privatelink.file.core.windows.net"
resource azurerm_private_dns_cname_record file_to_privatelinkfile_cname {
  name                  = local.data_sub_st_name
  zone_name             = azurerm_private_dns_zone.file_core_windows_net.name # "file.core.windows.net"
  resource_group_name   = data.azurerm_resource_group.hub_vnet_rg.name
  ttl                   = 300
  record                = "${local.data_sub_st_name}.${azurerm_private_dns_zone.privatelink_file_core_windows_net.name}"
  tags                  = local.base_tags
}

#   / ###   PE to ACR in Data Subscription
#     / Not doing as requires Premium ACR which is costy

