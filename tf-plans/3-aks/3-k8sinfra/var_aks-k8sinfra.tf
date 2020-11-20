#--------------------------------------------------------------
#   Terraform Variables Declarations
#--------------------------------------------------------------
#   / Kubernetes Infrastructure
#--------------------------------------------------------------
variable piping_name      { default = "" }
variable deploy_ilb       { type = bool }
variable ilb_ip_suffix    { default = "" }