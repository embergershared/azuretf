#   ===  AzureRM provider connection  ===
variable "tenant_id"        {}
variable "subscription_id"  {}
variable "tf_app_id"        {}
variable "tf_app_secret"    {}

#   ===  Hub Base Services  ===
variable "base_rg_name"     {}
variable "base_laws_name"   {}
variable "base_stoacct_name"{}
variable "base_kv_name"     {}

#   ===  Hub Networking Services  ===
variable "hub_rg_name"      {}
variable "hub_vnet_name"    {}
variable "hub_fw_ip"        {}

#   ===  Private AKS  ===
variable "aks_base_name"    {}