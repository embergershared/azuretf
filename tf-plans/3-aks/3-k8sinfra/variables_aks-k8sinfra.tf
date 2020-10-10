#--------------------------------------------------------------
#   Terraform Variables Declarations
#--------------------------------------------------------------
#   / Kubernetes Infrastructure
#--------------------------------------------------------------
variable piping_name      { default = "" }
variable deploy_ilb       { type = bool }
variable ilb_ip_suffix    { default = "" }

#--------------------------------------------------------------
#   / Secrets to use for Data subscription access
#--------------------------------------------------------------
variable data_sub_tfsp_tenantid_kvsecret        {}
variable data_sub_tfsp_subid_kvsecret           {}
variable data_sub_tfsp_appid_kvsecret           {}
variable data_sub_tfsp_secret_kvsecret          {}