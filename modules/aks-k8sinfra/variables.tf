#--------------------------------------------------------------
#   / Kubernetes Infrastructure
#--------------------------------------------------------------
variable piping_name            { default = "" }
variable deploy_ilb             { type = bool }
variable ilb_ip_suffix          { default = "" }

#--------------------------------------------------------------
#   / AKS cluster
#--------------------------------------------------------------
variable aks_cluster_name       {}
variable aks_cluster_rg_name    {}

#--------------------------------------------------------------
#   / Key Vault
#--------------------------------------------------------------
variable aks_sub_kv_id                    {}
variable data_sub_tfsp_tenantid_kvsecret  {}
variable data_sub_tfsp_subid_kvsecret     {}
variable data_sub_tfsp_appid_kvsecret     {}
variable data_sub_tfsp_secret_kvsecret    {}

#--------------------------------------------------------------
#   / Modules dependencies
#--------------------------------------------------------------
variable dependencies {
  type        = list(any)
  description = "Specifies the modules that this module depends on."
  default     = []
}