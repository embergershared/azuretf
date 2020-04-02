#   ===  AzureRM provider connection  ===
variable "tenant_id"        {}
variable "subscription_id"  {}
variable "tf_app_id"        {}
variable "tf_app_secret"    {}

#   ===  Connection to Hub Base Services  ===
variable "base_rg_name"     {}
variable "base_laws_name"   {}
variable "base_stoacct_name"{}
variable "base_kv_name"     {}
variable "base_acr_name"    {}

#   ===  Base name for Hub Networking resources  ===
variable "hub_vnet_base_name"   {}
variable "hub_vnet_location"    {}

#   ===  Base name for Jumpboxes resources  ===
variable "hub_vms_base_name"    {}
variable "hub_vms_winbase_name" {}