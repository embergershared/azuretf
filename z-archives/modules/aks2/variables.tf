#   ===  Subscription Nickanme  ===
variable "subs_nickname"    {}

#   ===  Connect to Base Services  ===
variable "base_rg_name"      {}
variable "base_rg_location" {}

#   ===  Connect to Shared Services resources  ===
variable "sharedsvc_location"       {}
variable "sharedsvc_rg_name"        {}
variable "sharedsvc_laws_name"      {}
variable "sharedsvc_kv_name"        {}
variable "sharedsvc_acr_name"       {}

#   ===  Connect to Hub Networking resources  ===
variable "hub_vnet_base_name"       {}

#   ===  Data Resource Group  ===
variable data_rg_id                 {}

#   ===  AKS Cluster variables  ===
variable "calling_folder"           {}
variable "aks_sp_oid"               {}
variable "account_nickname"         {}
variable "aks_location"             {}
variable "aks_base_name"            {}
variable "aks_version"              {}
variable "aks_vnet_1stIP"           {}
variable "aks_nodesize"             {}
variable "aks_nodecount"            {}
variable "aks_dashboard"            {}
variable "aks_devspaces"            {}
variable "aks_connect_to_azfw"      {}
variable "aks_enable_privatelink"   {}