provider azuread {
  version = "~> 0.10.0"

  tenant_id       = var.tenant_id
  subscription_id = var.subscription_id
  client_id       = var.tf_app_id
  client_secret   = var.tf_app_secret
}
provider random {
  version = "~> 2.2"
}

locals {
  # Dates formatted
  now             = timestamp()
  nowUTC          = formatdate("YYYY-MM-DD hh:mm ZZZ", local.now) # 2020-06-16 14:44 UTC
  nowFormatted    = "${formatdate("YYYY-MM-DD", local.now)}T${formatdate("hh:mm:ss", local.now)}Z" # "2029-01-01T01:01:01Z"
  in3years        = timeadd(local.now, "26280h")
  in3yFormatted   = "${formatdate("YYYY-MM-DD", local.in3years)}T${formatdate("hh:mm:ss", local.in3years)}Z" # "2029-01-01T01:01:01Z"

  module_tags = merge(var.base_tags, "${map(
    "file-encoding", "utf-8",
    "TfModule", "/modules/azsp/main.tf",
  )}")
}

#--------------------------------------------------------------
#   Azure Service Principal
#--------------------------------------------------------------
#   / Create Azure AD Application, SP and Password
resource azuread_application azsp_app {
  count           = var.can_create_azure_servprincipals ? 1 : 0

  name            = lower("sp-${var.sp_naming}")
}
resource azuread_service_principal azsp_sp {
  count           = var.can_create_azure_servprincipals ? 1 : 0

  application_id  = azuread_application.azsp_app[0].application_id
}
resource random_uuid azsp_secret {
  count           = var.can_create_azure_servprincipals ? 1 : 0

  keepers = { rotateSecret = var.rotate_sp_secret }
 }
resource azuread_application_password azsp_app_pwd {
  count           = var.can_create_azure_servprincipals ? 1 : 0

  application_object_id = azuread_application.azsp_app[0].id
  value                 = random_uuid.azsp_secret[0].result
  end_date              = local.in3yFormatted # local.in3yFormatted | "2025-01-01T01:01:01Z"

  lifecycle { ignore_changes = [ end_date ] }
}
#   / Store AppId & AppSecret in Key Vault
resource azurerm_key_vault_secret azsp_appid_secret {
  count           = var.can_create_azure_servprincipals ? 1 : 0

  name            = lower("${azuread_application.azsp_app[0].name}-id")
  content_type    = azuread_application.azsp_app[0].name
  key_vault_id    = var.kv_id
  value           = azuread_application.azsp_app[0].application_id
  expiration_date = azuread_application_password.azsp_app_pwd[0].end_date
  not_before_date = local.nowFormatted

  tags      = local.module_tags
  lifecycle { ignore_changes  = [ tags, not_before_date, expiration_date ] }
}
resource azurerm_key_vault_secret azsp_apppwd_secret {
  count           = var.can_create_azure_servprincipals ? 1 : 0

  name            = lower("${azuread_application.azsp_app[0].name}-secret")
  content_type    = azuread_application.azsp_app[0].name
  key_vault_id    = var.kv_id
  value           = azuread_application_password.azsp_app_pwd[0].value
  expiration_date = azuread_application_password.azsp_app_pwd[0].end_date
  not_before_date = local.nowFormatted

  tags      = local.module_tags
  lifecycle { ignore_changes  = [ tags, not_before_date, expiration_date ] }
}
