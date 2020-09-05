#--------------------------------------------------------------
#   Terraform Variables Declarations
#--------------------------------------------------------------
#   / Hub Networking
#--------------------------------------------------------------
variable hub_vnet_base_name           {}
variable hub_vnet_prefix              {}
variable vpn_clients_address_space    {}
variable p2srootcert_file_path        {}

variable hub_vnet_deploy_azfw         { type = bool }
variable hub_vnet_deploy_vnetgw       { type = bool }