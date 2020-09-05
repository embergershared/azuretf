#--------------------------------------------------------------
#   Terraform Variables Declarations
#--------------------------------------------------------------
#   / AKS Cluster mandatory
#--------------------------------------------------------------
variable ssh_pubkey_path    {}
variable cluster_name       {}
variable cluster_location   {}
variable aks_vnet_cidr      { description = "/20 address space" }
variable ilb_vnet_cidr      { description = "/24 address space" }
variable k8s_version        { description = "check with: az aks get-versions --location canadacentral --output table"}
variable rotate_aks_secret  { type = bool }
#   ===  Cluster Admin role binding association  ===
variable aks_cluster_admins_AADIds  { type = map }
variable aks_sp_appid             { default = null }
variable aks_sp_appsecret         { default = null }
variable aks_sp_objid             { default = null }

#--------------------------------------------------------------
#   / AKS Cluster optional settings with defaults
#--------------------------------------------------------------
variable enable_privcluster         {}
variable enable_podsecurpol         {}
variable enable_omsagent            {}
variable enable_devspaces           {}
variable enable_kdash               {}
variable enable_azpolicy            {}
variable enable_aci                 {}
variable authorized_ips             {}

variable linx_admin_user            {}

variable default_np_name            {}
variable default_np_vmsize          {}
variable default_np_type            {}
variable default_np_enablenodepubip {}
variable default_np_osdisksize      {}
variable default_np_enableautoscale {}
variable default_np_nodecount       {}
variable default_np_maxpods         {}

variable network_plugin             {}
variable network_policy             {}
variable outbound_type              {}
variable load_balancer_sku          {}