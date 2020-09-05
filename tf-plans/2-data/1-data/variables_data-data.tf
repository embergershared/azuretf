
#--------------------------------------------------------------
#   Terraform Variables Declarations
#--------------------------------------------------------------
#   / Data resources
#--------------------------------------------------------------
variable data_location            {}
variable data_env                 {}
variable rotate_sql_secret        { type = bool }
variable sql_dbs                  { type = set(string) }
variable sql_sp_appid             { default = null }
variable sql_sp_appsecret         { default = null }