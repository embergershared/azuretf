#--------------------------------------------------------------
#   Terraform Variables Declarations
#--------------------------------------------------------------
#   / AKS Cluster mandatory
#--------------------------------------------------------------
variable cluster_location             {}
variable aks_vnet_cidr                { description = "/20 address space" }
variable k8s_version                  { description = "check with: az aks get-versions --location canadacentral --output table"}
variable subs_nickname                {}
variable cluster_name                 {}
variable aks_sp_appid                 { default = null }
variable aks_sp_appsecret             { default = null }
variable aks_sp_objid                 { default = null }
variable admin_group_object_ids       { default = null }
variable laws_id                      { default = null }
variable secrets_kv_id                {}
variable hub_vnet_name                {}
variable hub_rg_name                  {}
variable base_tags                    {}
variable hub_vnet_deploy_vnetgw       {}
variable hub_vnet_deploy_azfw         {}
variable hub_azfw_name                {}

#--------------------------------------------------------------
#   / AKS Cluster optional settings with defaults
#--------------------------------------------------------------
variable enable_privcluster           {}     # false
variable enable_podsecurpol           {}     # false
variable enable_omsagent              {}     # true
variable enable_devspaces             {}     # false
variable enable_kdash                 {}     # false
variable enable_azpolicy              {}     # false
variable enable_aci                   {}     # false
variable linx_admin_user              {}     # azureuser
variable authorized_ips               {}     # "*"

#   / Default Node Pool (https://docs.microsoft.com/en-us/cli/azure/ext/aks-preview/aks/nodepool?view=azure-cli-latest)
variable default_np_name              {}     # linuxpool
variable default_np_vmsize            {}     # Standard_B2s
variable default_np_type              {}     # VirtualMachineScaleSets
variable default_np_enablenodepubip   {}     # false
variable default_np_osdisksize        {}     # Minimum 30GB
variable default_np_availzonescount   {}
variable default_np_enableautoscale   { type = bool }     # false
variable default_np_nodecount         {}     # 3
variable default_np_maxpods           {}     # kubenet=> max 110 | azure/cni=> max 250, default 30
variable default_np_max_count         { default = null }  # Range: 1 - 100 or null
variable default_np_min_count         { default = null }  # Range: 1 - 100 or null

#   / Networking profile 
variable network_plugin               {}     # Enum: kubenet | azure
variable network_policy               {}     # Enum: azure | calico   (if azure, network_plugin must be azure) https://docs.microsoft.com/en-us/azure/aks/use-network-policies
variable outbound_type                {}     # Enum: loadBalancer | userDefinedRouting
variable load_balancer_sku            {}     # Standard
variable dns_service_ip               {}     # "10.0.0.10"
variable service_cidr                 {}     # "10.0.0.0/16"
variable docker_bridge_cidr           {}     # "172.17.0.1/16"

#   / Windows node pool
variable win_admin_username           {}     # "azureuser"
variable win_admin_password           { default = null }

#   / Autoscaler
variable balance_similar_node_groups        { default = null }
variable max_graceful_termination_sec       { default = null }
variable scale_down_delay_after_add         { default = null }
variable scale_down_delay_after_delete      { default = null }
variable scale_down_delay_after_failure     { default = null }
variable scan_interval                      { default = null }
variable scale_down_unneeded                { default = null }
variable scale_down_unready                 { default = null }
variable scale_down_utilization_threshold   { default = null }

#--------------------------------------------------------------
#   / Modules dependencies
#--------------------------------------------------------------
variable dependencies {
  type        = list(any)
  description = "Specifies the modules that this module depends on."
  default     = []
}