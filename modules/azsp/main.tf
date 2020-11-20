provider random {
  version = "~> 2.2"
}

locals {
  module_tags = merge(var.base_tags, "${map(
    "file-encoding", "utf-8",
    "TfModule", "/modules/az-sp/main.tf",
  )}")
}

#--------------------------------------------------------------
#   Azure Service Principal
#--------------------------------------------------------------
#   / Create Azure AD Application, SP and Password
resource azuread_application azsp_app {
  count           = var.create_az_sp ? 1 : 0

  name            = lower("sp-${var.subs_nickname}-${var.subs_adm_short}-${var.sp_naming}")
}
resource azuread_service_principal azsp_sp {
  count           = var.create_az_sp ? 1 : 0

  application_id  = azuread_application.azsp_app[0].application_id
}
resource random_uuid azsp_secret {
  count           = var.create_az_sp ? 1 : 0

  keepers = { rotateSecret = var.rotate_sp_secret }
 }
resource azuread_application_password azsp_app_pwd {
  count           = var.create_az_sp ? 1 : 0

  application_object_id = azuread_application.azsp_app[0].id
  value                 = random_uuid.azsp_secret[0].result
  end_date              = var.in3yearsUTCFormatted # local.in3yFormatted | "2025-01-01T01:01:01Z"

  lifecycle { ignore_changes = [ end_date ] }
}

#--------------------------------------------------------------
#   Store Service Principal info in Key Vault
#--------------------------------------------------------------
#   / Store App Id, Name & Secret in Key Vault
resource azurerm_key_vault_secret azsp_appid_secret {
  count           = var.create_az_sp ? 1 : 0

  name            = lower("${var.subs_nickname}-sp-${var.sp_naming}")
  key_vault_id    = var.kv_id
  content_type    = azuread_application.azsp_app[0].name
  expiration_date = azuread_application_password.azsp_app_pwd[0].end_date
  not_before_date = var.nowUTCFormatted

  value           = jsonencode({
                      "sp-appname"    = azuread_application.azsp_app[0].name,
                      "sp-appid"      = azuread_application.azsp_app[0].application_id,
                      "sp-appsecret"  = azuread_application_password.azsp_app_pwd[0].value,
                      "sp-objid"      = azuread_service_principal.azsp_sp[0].object_id})

  tags = merge(local.module_tags, "${map(
    "file-encoding", "utf-8",
  )}")
  lifecycle { ignore_changes  = [ tags["BuiltOn"], ] }
}