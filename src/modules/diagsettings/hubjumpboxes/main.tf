#--------------------------------------------------------------
#   Diag Settings for Hub Jumpboxes
#--------------------------------------------------------------
#   / NSGs module
module nsgs_diag {
  source              = "../nsgs"

  # NSGs Diag Setting instance specific
  rg_name             = var.jumpboxes_rg_name
  mainloc_stacct      = var.mainloc_stacct
  secondloc_stacct    = var.secondloc_stacct
  laws_id             = var.laws_id
  retention_days      = var.retention_days
}
#   / NICs module
module nics_diag {
  source              = "../nics"

  # NICs Diag Setting instance specific
  rg_name             = var.jumpboxes_rg_name
  mainloc_stacct      = var.mainloc_stacct
  secondloc_stacct    = var.secondloc_stacct
  laws_id             = var.laws_id
  retention_days      = var.retention_days
}
#   / Public IPs module
module pubips_diag {
  source              = "../publicips"

  # Public IPs Diag Setting instance specific
  rg_name             = var.jumpboxes_rg_name
  mainloc_stacct      = var.mainloc_stacct
  secondloc_stacct    = var.secondloc_stacct
  laws_id             = var.laws_id
  retention_days      = var.retention_days
}