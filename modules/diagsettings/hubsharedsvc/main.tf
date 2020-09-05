#--------------------------------------------------------------
#   Diag Settings for Items types in Hub Shared Services
#--------------------------------------------------------------
#   / ACRs module
module acrs_diag {
  source              = "../acrs"

  # ACR Diag Setting instance specific
  rg_name         = var.sharedsvc_rg_name
  stacct_id       = var.stacct_id
  laws_id         = var.laws_id
  retention_days  = var.retention_days
}
#   / Key Vaults module
module kv_diag {
  source              = "../keyvaults"

  # Key Vault Diag Setting instance specific
  rg_name         = var.sharedsvc_rg_name
  stacct_id       = var.stacct_id
  laws_id         = var.laws_id
  retention_days  = var.retention_days
}