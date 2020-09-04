#   Create Terraform Service Principal PowerSjhel script
#
# 1. Login to Azure
az login
# Choose the account to use in Azure in browser

# Set the variables
$subscription_id="sub"
$subscription_nickname="subnickname"
$TfSpSuffix1="suffix"
$TfSpSuffix2="Terraform"
$kvVaultName="keyvaultname"

# Process variables
$TfSpName = "${subscription_nickname}-${TfSpSuffix1}-${TfSpSuffix2}"
$scriptName = $MyInvocation.MyCommand.Name

# Process Dates
$Time = Get-Date
$expDate = $(Get-Date -Date $Time.AddDays(364).ToUniversalTime() -Format "yyyy-MM-ddTHH:mm:ssZ") # 2020-04-05T17:15:13Z
$actDate = $(Get-Date -Date $Time.AddMinutes(-1).ToUniversalTime() -Format "yyyy-MM-ddTHH:mm:ssZ")

# Set the subscription
az account set --subscription $subscription_id

# Check if the SP already exists
$existing_app_id=$(az ad sp list --display-name $TfSpName --query [].appId -o tsv)
$appExists = !($null -eq $existing_app_id)

if ($appExists) {
    # Refresh its secret
    $tf_app_id = $existing_app_id
    $tf_app_secret = $(az ad sp credential reset --name $tf_app_id --query password -o tsv)
} else {
    # Create the Terraform Service Principal
    $tf_app = $(az ad sp create-for-rbac --name $TfSpName --role="Contributor" --scopes="/subscriptions/$subscription_id" --query '[appId, password]' -o tsv)
    $tf_app_id = $tf_app[0]
    $tf_app_secret = $tf_app[1]
}

# Check/give the RBAC access required to the Terraform Service Principal
#   - Contributor on the Subscription
$role="Contributor"
az role assignment create --role $role --assignee $tf_app_id --subscription $subscription_id

#   - User Access Administrator on the Subscription
$role="User Access Administrator"   # To give: Microsoft.Authorization/roleAssignments/write and Microsoft.Authorization/roleAssignments/delete permissions
az role assignment create --role $role --assignee $tf_app_id --subscription $subscription_id

# # Test Service Principal Login
# az logout
# az login --service-principal -u $tf_app_id -p $tf_app_secret --tenant $tenant_id
# az account set --subscription $subscription_id

# Get the Tenant Id
$tenant_id=$(az account show --query tenantId -o tsv)

# Display results
if ($appExists) {
    Write-Host "======     Terraform Service Principal refreshed  ======"
} else {
    Write-Host "======     Terraform Service Principal created    ======"
}
Write-Host "    DisplayName: $TfSpName"
Write-Host "       TenantId: $tenant_id"
Write-Host " SubscriptionId: $subscription_id"
Write-Host "          AppId: $tf_app_id"
Write-Host "      AppSecret: $tf_app_secret"

# Update/Create the Key Vault secrets
Write-Host ""
Write-Host     "======     Updating secrets in Key Vault ${kvVaultName}  ======"
az keyvault secret set --name "${TfSpName}-AppId" `
    --vault-name "${kvVaultName}" --value $tf_app_id --description $TfSpName `
    --tags CreatedBy=$scriptName `
    --query id -o tsv `
    --expires $expDate --not-before $actDate

az keyvault secret set --name "${TfSpName}-AppSecret" `
    --vault-name "${kvVaultName}" --value $tf_app_secret --description $TfSpName `
    --tags CreatedBy=$scriptName `
    --query id -o tsv `
    --expires $expDate --not-before $actDate

az keyvault secret set --name "${TfSpName}-SubId" `
    --vault-name "${kvVaultName}" --value $subscription_id --description $TfSpName `
    --tags CreatedBy=$scriptName `
    --query id -o tsv `
    --expires $expDate --not-before $actDate