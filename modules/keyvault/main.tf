locals {
  module_tags = merge(var.base_tags, "${map(
    "TfModule", "/modules/keyvault/main.tf",
  )}")
}

#--------------------------------------------------------------
#   Hub Shared Services / Azure Key Vault
#--------------------------------------------------------------
#   / Azure Key Vault
resource azurerm_key_vault kv {
  name                            = var.name
  resource_group_name             = var.resource_group_name
  location                        = var.location
  tenant_id                       = var.tenant_id
  sku_name                        = "standard"
  soft_delete_enabled             = true
  purge_protection_enabled        = true
  enabled_for_disk_encryption     = true
  enabled_for_template_deployment = false
  enabled_for_deployment          = false

  network_acls {
    bypass                     = "AzureServices"
    default_action             = "Deny"
    ip_rules                   = var.public_internet_ips_to_allow
    virtual_network_subnet_ids = var.virtual_network_subnet_ids
  }

  tags      = local.module_tags
  lifecycle { ignore_changes = [tags["BuiltOn"]] }
}
#   / Azure Key Vault Management Plane Access
resource azurerm_role_assignment owner_role_to_kv_assignment {
  for_each             = var.sharedsvc_kv_owners

  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Owner"
  principal_id         = each.value
}
#   / Azure Key Vault Data Plane Access Policies
resource azurerm_key_vault_access_policy full_access_policy {
  for_each        = var.sharedsvc_kv_fullaccess

  key_vault_id    = azurerm_key_vault.kv.id
  tenant_id       = var.tenant_id
  object_id       = each.value

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
#        / for user: Terraform Service Principal
resource azurerm_key_vault_access_policy terraform_access_policy {
  key_vault_id    = azurerm_key_vault.kv.id
  tenant_id       = var.tenant_id
  object_id       = var.tf_sp_objid

  key_permissions = [
    "Get", "List", "Update", "Create", "Delete", "Recover", "Import", "Backup", "Restore",
    # Cryptographic options
    "Decrypt", "Encrypt", "UnwrapKey", "WrapKey", //"verify", "sign",
    // # Privileged key options
    // "purge",
  ]

  secret_permissions = [
    "Get", "List", "Set", "Delete", "Recover", "Backup", "Restore",
    // # Privileged key options
    // "purge",
  ]

  certificate_permissions = [
    "Get", "List", //"update", "create", "import", "delete", "recover", "backup", "restore",
    // # Certificates specific
    // "managecontacts", "manageissuers", "getissuers", "listissuers", "setissuers", "deleteissuers",
    // # Privileged key options
    // "purge",
  ]
}