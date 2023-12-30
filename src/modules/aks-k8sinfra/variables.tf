#--------------------------------------------------------------
#   / AKS cluster to deploy to
#--------------------------------------------------------------
variable aks_cluster_name       {}
variable aks_cluster_rg_name    {}

#--------------------------------------------------------------
#   / Kubernetes Infrastructure
#--------------------------------------------------------------
variable piping_name            { default = "" }
variable deploy_ilb             { type = bool }
variable ilb_ip_suffix          { default = "" }

#--------------------------------------------------------------
#   / Data Subscription Access
#--------------------------------------------------------------
#   / Service Principal to access subscription
variable data_sub_access_sp_tenantid  {}
variable data_sub_access_sp_appid     {}
variable data_sub_access_sp_secret    {}
#   / Private DNS Resource Group
variable privdns_rg_name              {}
#   / Key Vault Id
variable data_sub_kv_id               {}
#   / ACR name
variable data_sub_acr_name            {}

#--------------------------------------------------------------
#   / Modules dependencies & Tags
#--------------------------------------------------------------
variable base_tags                        {}
variable dependencies {
  type        = list(any)
  description = "Specifies the modules that this module depends on."
  default     = []
}