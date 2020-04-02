#   Create Terraform Service Principal PowerSjhel script
#
# 1. Login to Azure
az login
# Choose the account to use in Azure

# Set the subscription
$tenant_id="XYZ"
$subscription_id="XYZ"
az account set --subscription $subscription_id

# Create the Terraform Service Principal
az ad sp create-for-rbac --name "Terraform_EmBerger" --role="Contributor" --scopes="/subscriptions/$subscription_id"
# Getting the data back:
# {
#   "appId": "ABC",
#   "displayName": "Terraform_EmBerger",
#   "name": "http://Terraform_EmBerger",
#   "password": "ABC",
#   "tenant": "ABC"
# }

# Set appId & secret from the Service Principal output
$tf_app_id="ABC"
$tf_app_secret="DEF"

# Assign Terraform SP to the other subscription
az role assignment create --assignee $tf_app_id --role="Contributor" --scope="/subscriptions/$subscription_id"

# Test Service Principal Login
az login --service-principal -u $tf_app_id -p $tf_app_secret --tenant $tenant_id
az account set --subscription $subscription_id