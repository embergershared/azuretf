#   ===  AzureRM provider connection  ===
variable "tenant_id"        {}
variable "subscription_id"  {}
variable "tf_app_id"        {}
variable "tf_app_secret"    {}

#   ===  AKS Cluster Deployments  ===
variable "aks_cluster_admins_AADIds"   {
    default = {
        "user1@hotmail.com" = "ABC"
        "user2@microsoft.com" = "DEF"
    }
}