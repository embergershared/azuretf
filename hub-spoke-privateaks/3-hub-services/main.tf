# Description   : This Terraform resource set is used to:
#                 Implement the Hub and Spoke network topology with VNetGateway, Azure Firewall, ACR, and Key Vault
#                       https://docs.microsoft.com/en-us/azure/architecture/reference-architectures/hybrid-networking/hub-spoke
#                       https://docs.microsoft.com/en-us/azure/architecture/reference-architectures/hybrid-networking/shared-services
#                       https://docs.microsoft.com/en-us/azure/architecture/reference-architectures/hybrid-networking/vpn
#
#                       https://docs.microsoft.com/en-us/azure/firewall/tutorial-firewall-deploy-portal
#
#
#                 To use it, follow these steps:
#                   1. Set the values in the 3 variables files
#                   2. Generate the VNetGateway certificates as per:
#                       https://docs.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-howto-point-to-site-resource-manager-portal#generatecert
#                   3. Update the value in betwen this section around line 220
#                           public_cert_data = <<EOF
#                           
#                           EOF
#                   4. Plan / Apply the plan
#                   2. Once the infrastructure is created, fill in the KeyVault secrets by:
#                       a. Execute /resources/KV-AKS-Cluster-Secrets-Creation.sh
#                       b. Execute /resources/KV-AAD-RBAC-Creation.sh
#                       Note: read the scripts instructions before running them
#
# Directory     : /hub-spoke-privateaks/3-hub-services/
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

#   ===  Provider, Backend TF State, locals  ===
terraform {
backend azurerm {
    resource_group_name  = "Hub-BaseServices-RG"
    storage_account_name = "hubbasesvcstor"
    container_name       = "terraform-states"
    key                  = "3-hub-services.tfstate"
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
        "TfFolder", "/hub-spoke-privateaks/3-hub-services/",
        "BuiltOn","${local.timestamp}",
        "InitiatedBy", "EB",
        "RefreshedOn", "${local.timestamp}",        
    )}"
}

#   ===  Data collection  ===
data azurerm_client_config current {
    }
data azurerm_log_analytics_workspace base_laws {
    resource_group_name = var.base_rg_name
    name                = var.base_laws_name
    }
data azurerm_storage_account backendstoracct {
    resource_group_name  = var.base_rg_name
    name                 = var.base_stoacct_name
}

#   ===  Hub Networking Resource Group  ===
resource azurerm_resource_group hub_vnet_rg {
    name     = "${var.hub_vnet_base_name}-RG"
    location = var.hub_vnet_location

    tags = local.base_tags
    lifecycle {
        ignore_changes = [
            tags["BuiltOn"],
        ]
    }
}

#   ===  Hub Networking VNet  ===
resource azurerm_virtual_network hub_vnet {
    name                = "${var.hub_vnet_base_name}-VNet"
    resource_group_name = azurerm_resource_group.hub_vnet_rg.name
    location            = azurerm_resource_group.hub_vnet_rg.location
    address_space       = ["10.1.0.0/16"]

    tags = local.base_tags
    lifecycle {
        ignore_changes = [
            tags["BuiltOn"],
        ]
    }
    }
#   ===     / Hub VNet Diag settings  ===
resource azurerm_monitor_diagnostic_setting hubvnet_diagrule {
    name                          = "${azurerm_virtual_network.hub_vnet.name}-DiagSettings"
    target_resource_id            = azurerm_virtual_network.hub_vnet.id
    storage_account_id            = data.azurerm_storage_account.backendstoracct.id
    log_analytics_workspace_id    = data.azurerm_log_analytics_workspace.base_laws.id

    log {
        category = "VMProtectionAlerts" # Azure Harcoded name
        enabled  = true
        retention_policy {
        days = 30
        enabled = true
        }
    }
    metric {
        category = "AllMetrics"         # Azure Harcoded name
        enabled  = true
        retention_policy {
        days = 30
        enabled = true
        }
    }
}

#   ===  Hub Networking VNetGateway  ===
#   ===     / VNet Gateway Subnet  ===
resource azurerm_subnet gw_subnet {
    name                    = "GatewaySubnet"       # Hardcoded requirement for VNetGateway ipconfiguration
    resource_group_name     = azurerm_resource_group.hub_vnet_rg.name
    virtual_network_name    = azurerm_virtual_network.hub_vnet.name
    address_prefix          = "10.1.0.32/27"
}
#   ===     / VNet Gateway Public IP  ===
resource azurerm_public_ip p2s_vpn_pip {
    name                = "${var.hub_vnet_base_name}-VNetGateway-PIP"
    resource_group_name = azurerm_resource_group.hub_vnet_rg.name
    location            = azurerm_resource_group.hub_vnet_rg.location
    allocation_method   = "Dynamic"

    tags = local.base_tags
    lifecycle {
        ignore_changes = [
            tags["BuiltOn"],
        ]
    }
}
#   ===     / VNet Gateway Public IP Diag settings  ===
resource azurerm_monitor_diagnostic_setting vpngw_pip_diagrule {
    name                          = "${azurerm_public_ip.p2s_vpn_pip.name}-DiagSettings"
    target_resource_id            = azurerm_public_ip.p2s_vpn_pip.id
    storage_account_id            = data.azurerm_storage_account.backendstoracct.id
    log_analytics_workspace_id    = data.azurerm_log_analytics_workspace.base_laws.id

    log {
        category = "DDoSProtectionNotifications"   # Azure Harcoded name
        enabled  = true
        retention_policy {
        days = 30
        enabled = true
        }
    }
    log {
        category = "DDoSMitigationFlowLogs"       # Azure Harcoded name
        enabled  = true
        retention_policy {
        days = 30
        enabled = true
        }
    }
    log {
        category = "DDoSMitigationReports"       # Azure Harcoded name
        enabled  = true
        retention_policy {
        days = 30
        enabled = true
        }
    }
    metric {
        category = "AllMetrics"                  # Azure Harcoded name
        enabled  = true
        retention_policy {
        days = 30
        enabled = true
        }
    }
}
#   ===     / VNet Gateway in Point-To-Site VPN configuration  ===
resource azurerm_virtual_network_gateway hub_p2svpn_vgw {
    name                = "${var.hub_vnet_base_name}-VNetGateway"
    resource_group_name = azurerm_resource_group.hub_vnet_rg.name
    location            = azurerm_resource_group.hub_vnet_rg.location
    
    type            = "VPN"
    vpn_type        = "RouteBased"
    active_active   = false
    enable_bgp      = false
    sku             = "VpnGw1"
    generation      = "Generation1"

    ip_configuration {
        name                          = "VNetGatewayConfig"
        public_ip_address_id          = azurerm_public_ip.p2s_vpn_pip.id
        private_ip_address_allocation = "Dynamic"
        subnet_id                     = azurerm_subnet.gw_subnet.id
    }

    vpn_client_configuration {
        address_space = ["172.16.201.0/24"]

        vpn_client_protocols = [
            "IkeV2",
            "OpenVPN",
            ]

        root_certificate {
            name = "VNetGateway-P2S-RootCert"

            public_cert_data = <<EOF
            GA1UEAxMOUHJpdkFrcyBWUE4gQ0EwHBBQADggEPADCCAQoC6rT1OB0MPr......RlVNl
            EOF
            # Dumb data above
        }
    }

    tags = local.base_tags
    lifecycle {
        ignore_changes = [
            tags["BuiltOn"],
        ]
    }
}

#   ===  Hub Networking Azure Firewall  ===
#   ===     / AzureFirewall Subnet  ===
resource azurerm_subnet az_fw_subnet {
    name                    = "AzureFirewallSubnet"     # Hardcoded requirement for Azure Firewall ipconfiguration
    resource_group_name     = azurerm_resource_group.hub_vnet_rg.name
    virtual_network_name    = azurerm_virtual_network.hub_vnet.name
    address_prefix          = "10.1.0.64/26"            # Hardcoded requirement: at least /26 for Azure Firewall ipconfiguration
}
#   ===     / Azure Firewall Public IP  ===
resource azurerm_public_ip azfw_pip {
    name                = "${var.hub_vnet_base_name}-AzFirewall-PIP"
    resource_group_name = azurerm_resource_group.hub_vnet_rg.name
    location            = azurerm_resource_group.hub_vnet_rg.location
    sku                 = "Standard"
    allocation_method   = "Static"
    tags = local.base_tags
    lifecycle {
        ignore_changes = [
            tags["BuiltOn"],
    ]
    }
}
#   ===     / Azure Firewall Public IP Diag settings  ===
resource azurerm_monitor_diagnostic_setting azfw_pip_diagrule {
    name                          = "${azurerm_public_ip.azfw_pip.name}-DiagSettings"
    target_resource_id            = azurerm_public_ip.azfw_pip.id
    storage_account_id            = data.azurerm_storage_account.backendstoracct.id
    log_analytics_workspace_id    = data.azurerm_log_analytics_workspace.base_laws.id
    log {
        category = "DDoSProtectionNotifications"   # Azure Harcoded name
        enabled  = true
        retention_policy {
        days = 30
        enabled = true
        }
    }
    log {
        category = "DDoSMitigationFlowLogs"       # Azure Harcoded name
        enabled  = true
        retention_policy {
        days = 30
        enabled = true
        }
    }
    log {
        category = "DDoSMitigationReports"       # Azure Harcoded name
        enabled  = true
        retention_policy {
        days = 30
        enabled = true
        }
    }
    metric {
        category = "AllMetrics"                   # Azure Harcoded name
        enabled  = true
        retention_policy {
        days = 30
        enabled = true
        }
    }
}
#   ===     /  Azure Firewall  ===
resource azurerm_firewall hub_azfw {
    name                = "${var.hub_vnet_base_name}-AzFirewall"
    location            = azurerm_resource_group.hub_vnet_rg.location
    resource_group_name = azurerm_resource_group.hub_vnet_rg.name
    ip_configuration {
        name                 = "AzFwPublicIpConfig"
        subnet_id            = azurerm_subnet.az_fw_subnet.id
        public_ip_address_id = azurerm_public_ip.azfw_pip.id
    }
 
    tags = local.base_tags
    lifecycle {
        ignore_changes = [
            tags["BuiltOn"],
    ]
    }
}
#   ===     /  Azure Firewall Diag settings  ===
resource azurerm_monitor_diagnostic_setting fw_diagrule {
    name                          = "${azurerm_firewall.hub_azfw.name}-DiagSettings"
    target_resource_id            = azurerm_firewall.hub_azfw.id
    storage_account_id            = data.azurerm_storage_account.backendstoracct.id
    log_analytics_workspace_id    = data.azurerm_log_analytics_workspace.base_laws.id
    log {
        category = "AzureFirewallApplicationRule"   # Azure Harcoded name
        enabled  = true
        retention_policy {
        days = 30
        enabled = true
        }
    }
    log {
        category = "AzureFirewallNetworkRule"       # Azure Harcoded name
        enabled  = true
        retention_policy {
        days = 30
        enabled = true
        }
    }
    metric {
        category = "AllMetrics"                     # Azure Harcoded name
        enabled  = true
        retention_policy {
        days = 30
        enabled = true
        }
    }
}

#   ===  Hub Jumpboxes VMs Resource Group ===
resource azurerm_resource_group "jumpbox_win_rg" {
    name     = "${var.hub_vms_base_name}-RG"
    location = var.hub_vnet_location

    tags = local.base_tags
    lifecycle {
        ignore_changes = [
            tags["BuiltOn"],
    ]
    }
}

#   ===  Hub Jumpboxes VMs Network Security Group  ===
resource azurerm_network_security_group vms_nsg {
    name                    = "${var.hub_vms_winbase_name}-VMs-NSG"
    resource_group_name     = azurerm_resource_group.jumpbox_win_rg.name
    location                = azurerm_resource_group.jumpbox_win_rg.location

    tags = local.base_tags
    lifecycle {
        ignore_changes = [
            tags["BuiltOn"],
    ]
    }
}
#   ===  / VMs NSG Diag settings  ===
resource azurerm_monitor_diagnostic_setting vms_nsg_diagrule {
    name                          = "${azurerm_network_security_group.vms_nsg.name}-DiagSettings"
    target_resource_id            = azurerm_network_security_group.vms_nsg.id
    storage_account_id            = data.azurerm_storage_account.backendstoracct.id
    log_analytics_workspace_id    = data.azurerm_log_analytics_workspace.base_laws.id

    log {
        category = "NetworkSecurityGroupEvent"   # Azure Harcoded name
        enabled  = true
        retention_policy {
            days = 30
            enabled = true
        }
    }
    log {
        category = "NetworkSecurityGroupRuleCounter"   # Azure Harcoded name
        enabled  = true
        retention_policy {
            days = 30
            enabled = true
        }
    }
}
#   ===  / VMs NSG Network Security Rules  ===
resource azurerm_network_security_rule AllowRdpIn {
    resource_group_name         = azurerm_network_security_group.vms_nsg.resource_group_name
    network_security_group_name = azurerm_network_security_group.vms_nsg.name
    
    name                        = "Allow-Rdp3389-In"
    priority                    = 200
    direction                   = "Inbound"
    access                      = "Allow"
    protocol                    = "TCP"
    
    source_address_prefix       = "VirtualNetwork"
    source_port_range           = "*"
    
    destination_address_prefix  = "VirtualNetwork"
    destination_port_range      = "3389"
}
resource azurerm_network_security_rule AllowHttp80In {
    resource_group_name         = azurerm_network_security_group.vms_nsg.resource_group_name
    network_security_group_name = azurerm_network_security_group.vms_nsg.name
    
    name                        = "Allow-Http80-In"
    priority                    = 250
    direction                   = "Inbound"
    access                      = "Allow"
    protocol                    = "TCP"
    
    source_address_prefix       = "VirtualNetwork"
    source_port_range           = "*"
    
    destination_address_prefix  = "VirtualNetwork"
    destination_port_range      = "80"
}

#   ===  Hub Jumpboxes VMs Subnet  ===
resource azurerm_subnet jumpboxes_subnet {
    name                    = "JumpboxesSubnet"
    resource_group_name     = azurerm_resource_group.hub_vnet_rg.name
    virtual_network_name    = azurerm_virtual_network.hub_vnet.name
    address_prefix          = "10.1.0.0/27"
}
#   ===     / Hub Jumpboxes VMs Subnet NSG association  ===
resource azurerm_subnet_network_security_group_association vms_subnet_to_nsg_association {
    subnet_id                   = azurerm_subnet.jumpboxes_subnet.id
    network_security_group_id   = azurerm_network_security_group.vms_nsg.id
}

#   ===     / Windows 2019 Jumpbox VM1  ===
#   ===         / NIC1  ===
resource azurerm_network_interface win2019_vm1_nic {
    name                = "${var.hub_vms_winbase_name}1-NIC"
    resource_group_name = azurerm_resource_group.jumpbox_win_rg.name
    location            = azurerm_resource_group.jumpbox_win_rg.location

    ip_configuration {
        name                          = "JumpboxesSubnet-NIC-IPConfig"
        subnet_id                     = azurerm_subnet.jumpboxes_subnet.id
        private_ip_address_allocation = "Dynamic"
    }
}
#   ===         / NIC1 Diag settings  ===
resource azurerm_monitor_diagnostic_setting win2019_vm1_nic_diagrule {
    name                          = "${azurerm_network_interface.win2019_vm1_nic.name}-DiagSettings"
    target_resource_id            = azurerm_network_interface.win2019_vm1_nic.id
    storage_account_id            = data.azurerm_storage_account.backendstoracct.id
    log_analytics_workspace_id    = data.azurerm_log_analytics_workspace.base_laws.id

    metric {
        category = "AllMetrics"                     # Azure Harcoded name
        enabled  = true
        retention_policy {
        days = 30
        enabled = true
        }
    }
}
#   ===         / NIC1 NSG association  ===
resource azurerm_network_interface_security_group_association win2019_vm1_nic_to_vms_nsg_association {
    network_interface_id      = azurerm_network_interface.win2019_vm1_nic.id
    network_security_group_id = azurerm_network_security_group.vms_nsg.id
}
#   ===         / Disk Encryption Set for VMs with KeyVault KEK  ===
resource azurerm_disk_encryption_set win_vms_encrypt {
    name                = "${var.hub_vms_winbase_name}-DisksEncrypt"
    resource_group_name = azurerm_resource_group.jumpbox_win_rg.name
    location            = azurerm_resource_group.jumpbox_win_rg.location
    key_vault_key_id    = azurerm_key_vault_key.win_vms_kek.id

    identity {
        type = "SystemAssigned"
        # Creates the Enterprise Application:
        #   Name : W2019-JBox-DisksEncrypt
        #   AppId: ABC
        #   ObjId: DEF
    }
}
#   ===         / Azure Windows 2019 VM1  ===
resource azurerm_windows_virtual_machine win_vm1 {
    name                = "${var.hub_vms_winbase_name}1-VM"
    resource_group_name = azurerm_resource_group.jumpbox_win_rg.name
    location            = azurerm_resource_group.jumpbox_win_rg.location
    size                = "Standard_DS1_v2"
    admin_username      = "SvrAdministr"
    admin_password      = "0401494P193J8Cs9"

    network_interface_ids = [
        azurerm_network_interface.win2019_vm1_nic.id,
    ]

    os_disk {
        name                    = "${var.hub_vms_winbase_name}1-OsDisk"
        caching                 = "ReadWrite"
        storage_account_type    = "Standard_LRS"
        disk_encryption_set_id  = azurerm_disk_encryption_set.win_vms_encrypt.id
    }

    source_image_reference {
        # Get the list with: az vm image list --location canadacentral
        offer     = "WindowsServer"
        publisher = "MicrosoftWindowsServer"
        sku       = "2019-Datacenter"
        version   = "latest"
    }

    tags = local.base_tags
    lifecycle {
        ignore_changes = [
            tags["BuiltOn"],
    ]
    }
}

#   ===  Hub Base Services Azure Key Vault  ===>>
#   ===     / Azure Key Vault
resource azurerm_key_vault base_kv {
    name                            = var.base_kv_name
    resource_group_name             = data.azurerm_log_analytics_workspace.base_laws.resource_group_name
    location                        = data.azurerm_log_analytics_workspace.base_laws.location
    tenant_id                       = data.azurerm_client_config.current.tenant_id
    sku_name                        = "standard"
    soft_delete_enabled             = true
    purge_protection_enabled        = true
    enabled_for_disk_encryption     = true
    enabled_for_template_deployment = true
    enabled_for_deployment          = true
   
    tags = local.base_tags
    lifecycle {
        ignore_changes = [
            tags["BuiltOn"],
    ]
    }
}
#   ===     / Azure Key Vault Diagnostics settings
resource azurerm_monitor_diagnostic_setting base_kv_diag {
    name                        = "KV-Diags-to-Backend"
    target_resource_id          = azurerm_key_vault.base_kv.id
    storage_account_id          = data.azurerm_storage_account.backendstoracct.id
    log_analytics_workspace_id  = data.azurerm_log_analytics_workspace.base_laws.id

    log {
        category    = "AuditEvent"
        enabled     = true

        retention_policy {
        enabled   = true
        days      = 7
        }
    }

    metric {
        category = "AllMetrics"

        retention_policy {
        enabled   = true
        days      = 7
        }
    }
}

#   ===     / Azure Key Vault Data Plane Access Policies
#               / for user: user1@hotmail.com
resource azurerm_key_vault_access_policy EbHotmailFullAccess {
    key_vault_id    = azurerm_key_vault.base_kv.id
    tenant_id       = var.tenant_id
    object_id       = "ABC"    # ObjectId for "user1@hotmail.com"

    key_permissions = [
        "get", "list", "update", "create", "import", "delete", "recover", "backup", "restore",
        # Cryptographic options
        "decrypt", "encrypt", "unwrapKey", "wrapKey", "verify", "sign",
        # Privileged key options
        "purge",
    ]

    secret_permissions = [
        "get", "list", "set", "delete", "recover", "backup", "restore",
        # Privileged key options
        "purge",
    ]

    certificate_permissions = [
        "get", "list", "update", "create", "import", "delete", "recover", "backup", "restore",
        # Certificates specific
        "managecontacts", "manageissuers", "getissuers", "listissuers", "setissuers", "deleteissuers",
        # Privileged key options
        "purge",
    ]
}
#               / for user: user2@microsoft.com
resource azurerm_key_vault_access_policy EbMicrosoftFullAccess {
    key_vault_id    = azurerm_key_vault.base_kv.id
    tenant_id       = var.tenant_id
    object_id       = "DEF"    # ObjectId for "user2@microsoft.com"

    key_permissions = [
        "get", "list", "update", "create", "import", "delete", "recover", "backup", "restore",
        # Cryptographic options
        "decrypt", "encrypt", "unwrapKey", "wrapKey", "verify", "sign",
        # Privileged key options
        "purge",
    ]

    secret_permissions = [
        "get", "list", "set", "delete", "recover", "backup", "restore",
        # Privileged key options
        "purge",
    ]

    certificate_permissions = [
        "get", "list", "update", "create", "import", "delete", "recover", "backup", "restore",
        # Certificates specific
        "managecontacts", "manageissuers", "getissuers", "listissuers", "setissuers", "deleteissuers",
        # Privileged key options
        "purge",
    ]
}
#               / for user: Terraform current user
resource azurerm_key_vault_access_policy TerraformAccess {
    key_vault_id    = azurerm_key_vault.base_kv.id
    tenant_id       = var.tenant_id
    object_id       = data.azurerm_client_config.current.object_id

    key_permissions = [
        "get", "list", "update", "create", //"delete", "import", "recover", "backup", "restore",
        # Cryptographic options
        "decrypt", "encrypt", "unwrapKey", "wrapKey", //"verify", "sign",
        // # Privileged key options
        // "purge",
    ]

    secret_permissions = [
        "get", "list", //"set", "delete", "recover", "backup", "restore",
        // # Privileged key options
        // "purge",
    ]

    certificate_permissions = [
        "get", "list", //"update", "create", "import", "delete", "recover", "backup", "restore",
        // # Certificates specific
        // "managecontacts", "manageissuers", "getissuers", "listissuers", "setissuers", "deleteissuers",
        // # Privileged key options
        // "purge",
    ]
}

#               / for user: Disk Encryption Set for VMs
resource azurerm_role_assignment "VmsDisksEncryptionReader" {
    scope                = azurerm_key_vault.base_kv.id
    role_definition_name = "Reader"
    principal_id         = "DEF"    # ObjectId for "VmsDisksEncryption"
}
resource azurerm_key_vault_access_policy VmsDiskEncryptionSetAccess {
    key_vault_id    = azurerm_key_vault.base_kv.id
    tenant_id       = var.tenant_id
    object_id       = "DEF"    # This ObjectId was found after the fact, as it was created by Managed Identity

    key_permissions = [
        "get", //"list", "update", "create", "delete", "import", "recover", "backup", "restore",
        # Cryptographic options
        "unwrapkey", "wrapkey", //"decrypt", "encrypt", "verify", "sign",
        // # Privileged key options
        // "purge",
    ]

    secret_permissions = [
        //"get", "list", "set", "delete", "recover", "backup", "restore",
        // # Privileged key options
        // "purge",
    ]

    certificate_permissions = [
        //"get", "list", "update", "create", "import", "delete", "recover", "backup", "restore",
        // # Certificates specific
        // "managecontacts", "manageissuers", "getissuers", "listissuers", "setissuers", "deleteissuers",
        // # Privileged key options
        // "purge",
    ]
}

#   ===     / VM Disks Key Encryption Key (KEK)  ===
resource azurerm_key_vault_key win_vms_kek {
    name         = "WindowsVMsKEK"
    key_vault_id = azurerm_key_vault.base_kv.id
    key_type     = "RSA"
    key_size     = 2048

    key_opts = [
        "decrypt",
        "encrypt",
        "unwrapKey",
        "wrapKey",
    ]
}


#   ===  Hub Base Azure Container Registry  ===
resource azurerm_container_registry "hub_acr" {
    name                    = var.base_acr_name
    resource_group_name     = data.azurerm_log_analytics_workspace.base_laws.resource_group_name
    location                = data.azurerm_log_analytics_workspace.base_laws.location
    sku                     = "Basic"
    admin_enabled           = false
    
    tags = local.base_tags
    lifecycle {
        ignore_changes = [
            tags["BuiltOn"],
        ]
    }
}
resource azurerm_monitor_diagnostic_setting "acr_diag" {
    name                        = "ACR-Diags-to-Backend"
    target_resource_id          = azurerm_container_registry.hub_acr.id
    storage_account_id          = data.azurerm_storage_account.backendstoracct.id
    log_analytics_workspace_id  = data.azurerm_log_analytics_workspace.base_laws.id

    log {
        category    = "ContainerRegistryRepositoryEvents"
        enabled     = true

        retention_policy {
        enabled   = true
        days      = 7
        }
    }
    
    log {
        category    = "ContainerRegistryLoginEvents"
        enabled     = true

        retention_policy {
        enabled   = true
        days      = 7
        }
    }

    metric {
        category = "AllMetrics"

        retention_policy {
        enabled   = true
        days      = 7
        }
    }
}