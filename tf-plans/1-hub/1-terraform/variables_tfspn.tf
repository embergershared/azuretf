#--------------------------------------------------------------
#   Terraform Variables Declarations
#--------------------------------------------------------------
#   / AzureRM provider
#--------------------------------------------------------------
variable tenant_id        {}
variable subscription_id  {}
variable tf_app_id        {}
variable tf_app_secret    {}

#--------------------------------------------------------------
#   / Subscription base
#--------------------------------------------------------------
variable subs_nickname    {}
variable main_location    {}
variable can_create_azure_servprincipals     { type = bool }