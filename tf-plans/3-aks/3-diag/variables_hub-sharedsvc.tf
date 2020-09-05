#--------------------------------------------------------------
#   Terraform Variables Declarations
#--------------------------------------------------------------
#   / Hub Shared Services
#--------------------------------------------------------------
variable sharedsvc_rg_name        {}
variable sharedsvc_kv_suffix      { default = "" }
variable sharedsvc_acr_suffix     { default = "" }
variable kv_owners                { type = map }
variable kv_fullaccess            { type = map }