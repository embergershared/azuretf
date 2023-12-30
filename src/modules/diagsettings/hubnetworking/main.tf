#--------------------------------------------------------------
#   Diag Settings for Items types in Hub Networking
#--------------------------------------------------------------
#   / Public IPs module
module pubips_diag {
  source              = "../publicips"

  # Public IPs Diag Setting instance specific
  rg_name             = var.networking_rg_name
  mainloc_stacct      = var.mainloc_stacct
  secondloc_stacct    = var.secondloc_stacct
  laws_id             = var.laws_id
  retention_days      = var.retention_days
}
#   / Setting VNet Diag setting
module vnet_diag {
  source              = "../vnets"

  # VNet Diag Setting instance specific
  rg_name             = var.networking_rg_name
  mainloc_stacct      = var.mainloc_stacct
  secondloc_stacct    = var.secondloc_stacct
  laws_id             = var.laws_id
  retention_days      = var.retention_days
}
#   / Setting VNet Gateways Diag setting
module vgw_diag {
  source              = "../vnetgateways"

  # VNet Gateway Diag Setting instance specific
  rg_name             = var.networking_rg_name
  mainloc_stacct      = var.mainloc_stacct
  secondloc_stacct    = var.secondloc_stacct
  laws_id             = var.laws_id
  retention_days      = var.retention_days
}
#   / Setting Application Gateways Diag setting
module agw_diag {
  source              = "../appgateways"

  # Application Gateway Diag Setting instance specific
  rg_name             = var.networking_rg_name
  mainloc_stacct      = var.mainloc_stacct
  secondloc_stacct    = var.secondloc_stacct
  laws_id             = var.laws_id
  retention_days      = var.retention_days
}
#   / Setting Azure Firewall Diag setting via module
module azfw_diag {
  source              = "../azfirewalls"

  # Azure Firewall Diag Setting instance specific
  rg_name             = var.networking_rg_name
  mainloc_stacct      = var.mainloc_stacct
  secondloc_stacct    = var.secondloc_stacct
  laws_id             = var.laws_id
  retention_days      = var.retention_days
}
#*/