output sp_id      { value = var.can_create_azure_servprincipals ? azuread_application.azsp_app[0].application_id : ""     }
output sp_secret  { value = var.can_create_azure_servprincipals ? azuread_application_password.azsp_app_pwd[0].value : "" }
output sp_objid   { value = var.can_create_azure_servprincipals ? azuread_service_principal.azsp_sp[0].object_id : ""     }