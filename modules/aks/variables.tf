#   ===  Mandatory Variables for the module  ===
variable calling_folder               {}
variable cluster_location             {}
variable aks_vnet_cidr                {}
variable ilb_vnet_cidr                {}
variable subs_nickname                {}
variable cluster_name                 {}
variable k8s_version                  {}
variable aks_sp_id                    {}
variable aks_sp_secret                {}
variable aks_sp_objid                 {}
variable linx_ssh_pubkey_path         {}
variable laws_id                      {}
variable acr_id                       {}
variable secrets_kv_id                {}
variable hub_vnet_name                {}
variable hub_rg_name                  {}
variable base_tags                    {}
variable hub_vnet_deploy_vnetgw       {}
variable hub_vnet_deploy_azfw         {}
variable aks_cluster_admins_AADIds    { type = map }

#   ===  Variables with defaults to set  ===
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
variable default_np_enableautoscale   {}     # false
variable default_np_nodecount         {}     # 3
variable default_np_maxpods           {}     # kubenet=> max 110 | azure/cni=> max 250, default 30

#   / Networking profile 
variable network_plugin               {}     # Enum: kubenet | azure
variable network_policy               {}     # Enum: azure | calico   (if azure, network_plugin must be azure) https://docs.microsoft.com/en-us/azure/aks/use-network-policies
variable outbound_type                {}     # Enum: loadBalancer | userDefinedRouting
variable load_balancer_sku            {}     # Standard