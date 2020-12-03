#--------------------------------------------------------------
#   Terraform Variables Declarations
#--------------------------------------------------------------
#   / AKS Cluster mandatory
#--------------------------------------------------------------
variable cluster_name               {}
variable cluster_location           {}
variable aks_vnet_cidr              { description = "/20 address space" }
variable k8s_version                { description = "check with: az aks get-versions --location canadacentral --output table"}
#   ===  Cluster Admin role binding association  ===
variable aks_sp_key                 {}
variable aks_sp_appid               { default = null }
variable aks_sp_appsecret           { default = null }
variable aks_sp_objid               { default = null }
variable admin_group_object_ids     { default = null }

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
variable authorized_ips             { default = null }

variable linx_admin_user            {}
variable win_admin_user             {}
variable win_admin_password         {}

variable default_np_name            {}
variable default_np_vmsize          {}
variable default_np_type            {}
variable default_np_enablenodepubip {}
variable default_np_osdisksize      {}
variable default_np_enableautoscale {}
variable default_np_availzonescount { description = "check result: kubectl describe nodes | grep -e \"Name:\" -e \"failure-domain.beta.kubernetes.io/zone\"" }
variable default_np_nodecount       {}
variable default_np_maxpods         {}

variable network_plugin             {}
variable network_policy             {}
variable outbound_type              {}
variable load_balancer_sku          {}
variable dns_service_ip             {}
variable service_cidr               {}
variable docker_bridge_cidr         {}