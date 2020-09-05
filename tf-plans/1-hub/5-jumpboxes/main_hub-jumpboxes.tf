# Description   : This Terraform resource plan deploys:
#
#                 An Azure Hub Jumpbox with:
#                   - Jumpboxes RG:
#                      - Jumpboxes Subnet
#                      - NSG for the Jumpboxes subnet
#                      - a Jumpbox Virtual Machine (Windows, NIC, )
#                      - if the Hub network has an Azure Firewall, it connects the jumpbox subnet to it
#
#
# Folder/File   : /tf-plans/1-hub/5-jumpboxes/main_hub-jumpboxes.tf
# Terraform     : 0.13.+
# Providers     : azurerm 2.+
# Plugins       : none
# Modules       : none
#
# Created on    : 2020-04-11
# Created by    : Emmanuel
# Last Modified : 2020-07-10
# Last Modif by : Emmanuel

#--------------------------------------------------------------
#   Terraform Initialization
#--------------------------------------------------------------
terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
  }
  required_version = ">= 0.13"
}
provider azurerm {
  version         = "~> 2.12"
  features        {}

  tenant_id       = var.tenant_id
  subscription_id = var.subscription_id
  client_id       = var.tf_app_id
  client_secret   = var.tf_app_secret
}
locals {
  # Dates formatted
  now = timestamp()
  nowUTC = formatdate("YYYY-MM-DD hh:mm ZZZ", local.now) # 2020-06-16 14:44 UTC
  nowFormatted = "${formatdate("YYYY-MM-DD", local.now)}T${formatdate("hh:mm:ss", local.now)}Z" # "2029-01-01T01:01:01Z"
  in3years = timeadd(local.now, "26280h")
  in3yFormatted = "${formatdate("YYYY-MM-DD", local.in3years)}T${formatdate("hh:mm:ss", local.in3years)}Z" # "2029-01-01T01:01:01Z"

  # Tags values
  tf_plan   = "/tf-plans/1-hub/5-jumpboxes"

  base_tags = "${map(
    "BuiltBy", "Terraform",
    "TfPlan", "${local.tf_plan}/main_hub-jumpboxes.tf",
    "TfValues", "${local.tf_values}/",
    "TfState", "${local.tf_state}",
    "BuiltOn","${local.nowUTC}",
    "InitiatedBy", "User",
  )}"

  # Location short for Main location
  shortl_main_location  = lookup({
      canadacentral   = "cac", 
      canadaeast      = "cae",
      eastus          = "use" },
    lower(var.main_location), "")
}

#--------------------------------------------------------------
#   Data collection of required resources
#--------------------------------------------------------------
#   / Hub networking Resource Group
data azurerm_resource_group hub_vnet_rg {
  name        = lower("rg-${local.shortl_main_location}-${var.subs_nickname}-${var.hub_vnet_base_name}")
}
#   / Hub networking VNet
data azurerm_virtual_network hub_vnet {
  name                = lower("vnet-${local.shortl_main_location}-${var.subs_nickname}-${var.hub_vnet_base_name}")
  resource_group_name = data.azurerm_resource_group.hub_vnet_rg.name
}

#--------------------------------------------------------------
#   Hub Networking / Jumpboxes
#--------------------------------------------------------------
#   / Jumpboxes Resource Group
resource azurerm_resource_group jumpbox_win_rg {
  name        = lower("rg-${local.shortl_main_location}-${var.subs_nickname}-${var.hub_vms_base_name}")
  location    = var.main_location

  tags = merge(local.base_tags, "${map(
    "RefreshedOn", "${local.nowUTC}",
  )}")
  lifecycle { ignore_changes = [tags["BuiltOn"]] }
}
#   / VMs' subnet Network Security Group
resource azurerm_network_security_group vms_subnet_nsg {
  name        = lower("nsg-${local.shortl_main_location}-${var.subs_nickname}-snet-jumpboxes")

  resource_group_name     = azurerm_resource_group.jumpbox_win_rg.name
  location                = azurerm_resource_group.jumpbox_win_rg.location

  tags = local.base_tags
  lifecycle { ignore_changes = [ tags ] }
}
#   / VMs NSG Network Security Rules
resource azurerm_network_security_rule In_Allow_VnetRdp3389 {
  resource_group_name         = azurerm_network_security_group.vms_subnet_nsg.resource_group_name
  network_security_group_name = azurerm_network_security_group.vms_subnet_nsg.name
  
  name                        = "In-Allow-VnetRdp3389"
  priority                    = 1000
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "TCP"
  
  source_address_prefix       = "VirtualNetwork"
  source_port_range           = "*"
  
  destination_address_prefix  = "VirtualNetwork"
  destination_port_range      = "3389"
}
resource azurerm_network_security_rule In_Allow_PcEbRdp3389 {
  resource_group_name         = azurerm_network_security_group.vms_subnet_nsg.resource_group_name
  network_security_group_name = azurerm_network_security_group.vms_subnet_nsg.name
  
  name                        = "In-Allow-PcEbRdp3389"
  priority                    = 1050
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "TCP"
  
  source_address_prefix       = "45.44.243.251/32"
  source_port_range           = "*"
  
  destination_address_prefix  = "VirtualNetwork"
  destination_port_range      = "3389"
}
resource azurerm_network_security_rule In_Allow_VnetHttp80 {
  resource_group_name         = azurerm_network_security_group.vms_subnet_nsg.resource_group_name
  network_security_group_name = azurerm_network_security_group.vms_subnet_nsg.name
  
  name                        = "In-Allow-VnetHttp80"
  priority                    = 1100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "TCP"
  
  source_address_prefix       = "VirtualNetwork"
  source_port_range           = "*"
  
  destination_address_prefix  = "VirtualNetwork"
  destination_port_range      = "80"
}
resource azurerm_network_security_rule In_Allow_VnetHttps443 {
  resource_group_name         = azurerm_network_security_group.vms_subnet_nsg.resource_group_name
  network_security_group_name = azurerm_network_security_group.vms_subnet_nsg.name
  
  name                        = "In-Allow-VnetHttps443"
  priority                    = 1200
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "TCP"
  
  source_address_prefix       = "VirtualNetwork"
  source_port_range           = "*"
  
  destination_address_prefix  = "VirtualNetwork"
  destination_port_range      = "443"
}
#   / VMs Subnet
resource azurerm_subnet jumpboxes_subnet {
  name                    = "snet-jumpboxes"
  resource_group_name     = data.azurerm_resource_group.hub_vnet_rg.name
  virtual_network_name    = data.azurerm_virtual_network.hub_vnet.name
  address_prefixes        = [ replace(var.hub_vnet_prefix, "0/24", "0/27"), ]
}
#   / VMs Subnet NSG association
resource azurerm_subnet_network_security_group_association vms_subnet_to_nsg_association {
  subnet_id                   = azurerm_subnet.jumpboxes_subnet.id
  network_security_group_id   = azurerm_network_security_group.vms_subnet_nsg.id
}

#--------------------------------------------------------------
#   Hub Networking / Jumpboxes / Win2019 VM1
#--------------------------------------------------------------
#   / Public Internet IP Address
resource azurerm_public_ip win2019_vm1_pip1 {
  name                = "pip-${local.shortl_main_location}-${var.subs_nickname}-vm1-pip1"
  resource_group_name = azurerm_resource_group.jumpbox_win_rg.name
  location            = azurerm_resource_group.jumpbox_win_rg.location
  allocation_method   = "Dynamic"
}
#   / Internal NIC1
resource azurerm_network_interface win2019_vm1_nic1 {
  name                = "nic-${local.shortl_main_location}-${var.subs_nickname}-vm1-nic1"
  resource_group_name = azurerm_resource_group.jumpbox_win_rg.name
  location            = azurerm_resource_group.jumpbox_win_rg.location

  ip_configuration {
    name                          = "ipconf-nic-to-snet-jumpboxes"
    subnet_id                     = azurerm_subnet.jumpboxes_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.win2019_vm1_pip1.id
  }
}

/*
#   / Disks Key Encryption Key (KEK) for the Disk Encryption Set
resource azurerm_key_vault_key win_vms_kek {
  name         = "WindowsVMsKeyEncryptionKey1"
  key_vault_id = azurerm_key_vault.sharedsvc_kv.id
  key_type     = "RSA"
  key_size     = 2048

  key_opts = [
    "decrypt",
    "encrypt",
    "unwrapKey",
    "wrapKey",
  ]
}
#   / Disk Encryption Set for VMs with KeyVault KEK
resource azurerm_disk_encryption_set win_vms_encrypt {
  name                = "${var.hub_vms_winbase_name}-DisksEncrypt${local.shortd_sharedsvc_location}"
  resource_group_name = azurerm_resource_group.jumpbox_win_rg.name
  location            = azurerm_resource_group.jumpbox_win_rg.location
  key_vault_key_id    = azurerm_key_vault_key.win_vms_kek.id

  identity {
    type = "SystemAssigned"
    # Creates the Enterprise Application:
    #   Name : WJBox-DisksEncrypt-CAC
    #   AppId: 91d83977-dc17-446a-9d52-26d8724e367e
    #   ObjId: 88ca2f26-c98d-49de-9eda-3ebb37cac936
    #
    # And it must be given "Reader" permission in IAM of the KeyVault
  }
}
*/
#   / Windows 2019 VM1
resource azurerm_windows_virtual_machine win_vm1 {
  name                = "vm-${local.shortl_main_location}${var.subs_nickname}-1"

  resource_group_name = azurerm_resource_group.jumpbox_win_rg.name
  location            = azurerm_resource_group.jumpbox_win_rg.location
  size                = var.win_vm_size
  admin_username      = var.win_admin_user
  admin_password      = var.win_admin_pwd
  timezone            = "Eastern Standard Time"

  network_interface_ids = [
    azurerm_network_interface.win2019_vm1_nic1.id,
  ]

  os_disk {
    name                    = "disk-${local.shortl_main_location}-${var.subs_nickname}-vm1-os"
    caching                 = "ReadWrite"
    storage_account_type    = "Standard_LRS"
    #disk_encryption_set_id  = azurerm_disk_encryption_set.win_vms_encrypt.id
  }

  source_image_reference {
    # Get the list with: az vm image list --location canadacentral
    offer     = var.win_vm_offer
    publisher = var.win_vm_publisher
    sku       = var.win_vm_sku
    version   = var.win_vm_version
  }

  tags = local.base_tags
  lifecycle { ignore_changes = [ tags, os_disk[0].disk_encryption_set_id, ] }

  /*
  To install Windows Terminal, run in PowerShell as Admin:
    Set-ExecutionPolicy Bypass -Scope Process -Force;
    iex ((New-Object System.Net.WebClient).DownloadString(‘https://chocolatey.org/install.ps1’))
    choco install microsoft-windows-terminal
  */
}

#####################   Important Note  #######################
#     Due to Terraform 0.12 limitations on conditional
#     The Firewall Private IP is deducted and not gathered
#     v 0.13 with count on modules will solve this
#
#--------------------------------------------------------------
#   Hub Networking / Jumpboxes / AzFw connection (conditional)
#--------------------------------------------------------------
#   / Get Firewall in the Hub Networking RG
data azurerm_resources azfw_in_hub_netowkring_rg {
  resource_group_name = data.azurerm_resource_group.hub_vnet_rg.name
  type                = "Microsoft.Network/azureFirewalls"
}

/*
data azurerm_firewall hub_azfw {
  name                = data.azurerm_resources.azfw_in_hub_netowkring_rg.resources[0].name
  resource_group_name = data.azurerm_resource_group.hub_vnet_rg.name
}
*/

#   / Az Firewall Allow Access to *.com, *.ca & *.fr
resource azurerm_firewall_application_rule_collection Allow_Internet_Out {
  count               = var.hub_vnet_deploy_azfw ? 1 : 0

  name                = "AppRuleColl-Allow-Internet-Out"
  azure_firewall_name = data.azurerm_resources.azfw_in_hub_netowkring_rg.resources[0].name
  resource_group_name = data.azurerm_resource_group.hub_vnet_rg.name
  priority            = 100
  action              = "Allow"

  rule {
    name = "Access_Https443_to_COM_CA_FR"
    source_addresses = [ azurerm_subnet.jumpboxes_subnet.address_prefix , ]
    target_fqdns = [ "*.com", "*.ca", "*.fr", ]
    protocol {
      port = "443"
      type = "Https"
      }
    }

  rule {
    name = "Access_Http80_to_COM_CA_FR"
    source_addresses = [ azurerm_subnet.jumpboxes_subnet.address_prefix , ]
    target_fqdns = [ "*.com", "*.ca", "*.fr", ]
    protocol {
      port = "80"
      type = "Http"
    }
  }
}

#   / Az Firewall AKS Global required
resource azurerm_firewall_application_rule_collection Allow_AksGlobal_Out {
  count               = var.hub_vnet_deploy_azfw ? 1 : 0

  name                = "AppRuleColl-Allow-AksGlobalRequired-Out"
  azure_firewall_name = data.azurerm_resources.azfw_in_hub_netowkring_rg.resources[0].name
  resource_group_name = data.azurerm_resource_group.hub_vnet_rg.name
  priority            = 150
  action              = "Allow"

  rule {
    name              = "Access_Http80Https443_to_AksGlobal"
    source_addresses  = [ "*" , ]
    target_fqdns      = [  "aksrepos.azurecr.io", 
                          "*blob.core.windows.net" ,
                          "mcr.microsoft.com" ,
                          "*cdn.mscr.io" ,
                          "*.data.mcr.microsoft.com" ,
                          "management.azure.com" ,
                          "login.microsoftonline.com" ,
                          "ntp.ubuntu.com" ,
                          "packages.microsoft.com" ,
                          "acs-mirror.azureedge.net"
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

#--------------------------------------------------------------
#   Hub Networking / Azure Firewall / Jumpboxes routing to Az Fw
#--------------------------------------------------------------
#   / Hub Jumpboxes User Defined Route Table
resource azurerm_route_table vms_subnet_egress_udr {
  count                           = var.hub_vnet_deploy_azfw ? 1 : 0

  name                            = lower("routetable-${azurerm_subnet.jumpboxes_subnet.name}-egress-to-azfw")
  location                        = azurerm_resource_group.jumpbox_win_rg.location
  resource_group_name             = azurerm_resource_group.jumpbox_win_rg.name
  disable_bgp_route_propagation   = false

  route {
    name                    = lower("route-${azurerm_subnet.jumpboxes_subnet.name}-egress-to-azfw")
    address_prefix          = "0.0.0.0/0"
    next_hop_type           = "VirtualAppliance"
    #next_hop_in_ip_address  = data.azurerm_firewall.hub_azfw.ip_configuration[0].private_ip_address
    next_hop_in_ip_address  = replace(var.hub_vnet_prefix, "0/24", "132") # May create issues
  }
}
resource azurerm_subnet_route_table_association vms_subnet_egress_udr_subnet_association {
  count           = var.hub_vnet_deploy_azfw ? 1 : 0

  subnet_id       = azurerm_subnet.jumpboxes_subnet.id
  route_table_id  = azurerm_route_table.vms_subnet_egress_udr[0].id
}
#   / Block Internet Access for the VMs' Subnet at NSG level
resource azurerm_network_security_rule Out_Allow_VNet {
  count                       = var.hub_vnet_deploy_azfw ? 1 : 0

  resource_group_name         = azurerm_network_security_group.vms_subnet_nsg.resource_group_name
  network_security_group_name = azurerm_network_security_group.vms_subnet_nsg.name
  
  name                        = "Out-Allow-VNet"
  priority                    = 1000
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  
  source_address_prefixes     = [ azurerm_subnet.jumpboxes_subnet.address_prefix , ]
  source_port_range           = "*"
  
  destination_address_prefix  = "VirtualNetwork"
  destination_port_range      = "*"
}
resource azurerm_network_security_rule Out_Deny_Internet {
  count                       = var.hub_vnet_deploy_azfw ? 1 : 0

  resource_group_name         = azurerm_network_security_group.vms_subnet_nsg.resource_group_name
  network_security_group_name = azurerm_network_security_group.vms_subnet_nsg.name
  
  name                        = "Out-Deny-Internet"
  priority                    = 4096
  direction                   = "Outbound"
  access                      = "Deny"
  protocol                    = "*"
  
  source_address_prefixes     = [ azurerm_subnet.jumpboxes_subnet.address_prefix , ]
  source_port_range           = "*"
  
  destination_address_prefix  = "Internet"
  destination_port_range      = "*"
}