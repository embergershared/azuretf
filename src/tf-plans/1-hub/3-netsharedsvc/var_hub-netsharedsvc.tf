#--------------------------------------------------------------
#   Terraform Variables Declarations
#--------------------------------------------------------------
#   / Hub Networking
#--------------------------------------------------------------
variable hub_vnet_base_name           {}
variable hub_vnet_prefix              {}
variable vpn_clients_address_space    {}
variable p2s_ca_cert_file_path        {}

variable hub_vnet_deploy_azfw         { type = bool }
variable hub_vnet_deploy_vnetgw       { type = bool }

#--------------------------------------------------------------
#   / Hub Shared Services
#--------------------------------------------------------------
variable sharedsvc_rg_name            {}

#   / Key Vault settings
variable sharedsvc_kv_suffix          { default = "" }
variable sharedsvc_kv_owners          { type = map }
variable sharedsvc_kv_fullaccess      { type = map }
variable public_internet_ips_to_allow { type = list(string) }

#   / Azure Container Registry settings
variable sharedsvc_acr_deploy         { type = bool }
variable sharedsvc_acr_suffix         { default = "" }