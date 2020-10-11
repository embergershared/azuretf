
#--------------------------------------------------------------
#   Terraform Variables Declarations
#--------------------------------------------------------------
#   / Data resources
#--------------------------------------------------------------
variable data_location            {}
variable data_env                 {}

variable sql_deploy               { type = bool }
variable sql_rotate_secret        { type = bool }
variable sql_enable_security      { type = bool }
variable sql_dbs                  { type = set(string) }
variable sql_sp_appid             { default = null }
variable sql_sp_appsecret         { default = null }

variable aks_st_file_shares       { type = set(string) }