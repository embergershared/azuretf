output sp_id      { value = var.create_az_sp ? azuread_application.azsp_app[0].application_id : ""     }
output sp_secret  { value = var.create_az_sp ? azuread_application_password.azsp_app_pwd[0].value : "" }
output sp_objid   { value = var.create_az_sp ? azuread_service_principal.azsp_sp[0].object_id : ""     }