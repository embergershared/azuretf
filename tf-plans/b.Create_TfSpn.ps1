#   PowerShell script that Creates the Terraform Service Principal
#
#     The Service Principal gets the permissions:
#       - "Contributor" on Subscription:
#         > It allows the creation, modification and deletion of resources
#       - "User Access Administrator" on Subscription:
#         > It allows the creation, modification and deletion of role assignments
#
# 1. Login to Azure
az login
# Choose the account to use in Azure in browser

# 2.Set the variables
$subscription_id = ""   # Windows Azure MSDN
$subscription_nickname = ""
$TfSpSuffix1 = ""
$TfSpSuffix2 = "terraform"

# 3.Process the variables
$TfSpName = ("sp-${subscription_nickname}-${TfSpSuffix1}-${TfSpSuffix2}").ToLower()
$scriptName = $MyInvocation.MyCommand.Name

# 4.Process the dates for Console output
$Time = Get-Date
$expDate = $(Get-Date -Date $Time.AddDays(364).ToUniversalTime() -Format "yyyy-MM-ddTHH:mm:ssZ") # 2020-04-05T17:15:13Z
$actDate = $(Get-Date -Date $Time.AddMinutes(-1).ToUniversalTime() -Format "yyyy-MM-ddTHH:mm:ssZ")

# 5.Set the subscription
az account set --subscription $subscription_id

# 6.Check if the SP already exists
$existing_app_id=$(az ad sp list --display-name $TfSpName --query [].appId -o tsv)
$appExists = !($null -eq $existing_app_id)

# 7.Process depending of App registration status:
#   7a.If App exists, rotate its secret
if ($appExists) {
  # Refresh its secret
  $tf_app_id = $existing_app_id
  $tf_app_secret = $(az ad sp credential reset --name $tf_app_id --query password -o tsv)

#   7b.If App doesn't exist, create it
} else {
  # Create the Terraform Service Principal
  $tf_app = $(az ad sp create-for-rbac --name $TfSpName --role="Contributor" --scopes="/subscriptions/$subscription_id" --query '[appId, password]' -o tsv)
  $tf_app_id = $tf_app[0]
  $tf_app_secret = $tf_app[1]
}

# 8.Extract Current Role Assignments for the Service Principal
$currRoles=(az role assignment list --assignee $tf_app_id --query [].roleDefinitionName -o tsv)

# 9.Check/give the RBAC access required to the Terraform Service Principal
#   9a.Contributor on the Subscription
$role="Contributor"
if(!($currRoles -Contains $role)) {
  az role assignment create --role $role --assignee $tf_app_id --subscription $subscription_id }

#   9b.User Access Administrator on the Subscription
$role="User Access Administrator"   # To give: Microsoft.Authorization/roleAssignments/write and Microsoft.Authorization/roleAssignments/delete permissions
if(!($currRoles -Contains $role)) {
  az role assignment create --role $role --assignee $tf_app_id --subscription $subscription_id }

# 10.Get the Tenant Id
$tenant_id=$(az account show --query tenantId -o tsv)

# ### Debug: 11.Test Service Principal Login
# az logout
# az login --service-principal -u $tf_app_id -p $tf_app_secret --tenant $tenant_id
# az account set --subscription $subscription_id

# 12.Display the results
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


# # 13.Update/Create the Key Vault secrets
# Write-Host ""
# Write-Host     "======     Updating secrets in Key Vault ${kvVaultName}  ======"
# az keyvault secret set --name ("${TfSpName}-AppId").ToLower() `
#   --vault-name "${kvVaultName}" --value $tf_app_id --description $TfSpName `
#   --tags CreatedBy=$scriptName `
#   --query id -o tsv `
#   --expires $expDate --not-before $actDate

# az keyvault secret set --name ("${TfSpName}-AppSecret").ToLower() `
#   --vault-name "${kvVaultName}" --value $tf_app_secret --description $TfSpName `
#   --tags CreatedBy=$scriptName `
#   --query id -o tsv `
#   --expires $expDate --not-before $actDate

# az keyvault secret set --name ("${TfSpName}-SubId").ToLower() `
#   --vault-name "${kvVaultName}" --value $subscription_id --description $TfSpName `
#   --tags CreatedBy=$scriptName `
#   --query id -o tsv `
#   --expires $expDate --not-before $actDate

# 14.Give the Terraform Service Principal the permissions to Manage Azure AD
# Reference: https://www.terraform.io/docs/providers/azuread/guides/service_principal_configuration.html
#

# ############   In the portal:
# Azure Active Directory > App registrations > Select the right Service Principal ("sp-...")
# > API Permissions > Add a permission > APIs my organization uses > "Microsoft.Azure.ActiveDirectory" App (client) ID: 00000002-0000-0000-c000-000000000000
# > Application permissions > Application.ReadWrite.All > Ok
# > Grant admin consent for Microsoft Canada


#############   Through Script:
# Pre-reqs: Installed as Admin: install-module azuread, import-module azuread
Install-Module AzureAD -Force
Import-Module AzureAD

# Tenant connection
#$Admin = "gopher194@hotmail.com"
#$AdminPassword = ""
#$SecPass = ConvertTo-SecureString $AdminPassword -AsPlainText -Force
#$Cred = New-Object System.Management.Automation.PSCredential ($Admin, $SecPass)
Connect-AzureAD -TenantID $tenant_id #-Credential $cred

# Get the 'User Account Administrator' Role reference in Azure AD
$roleUAA = Get-AzureADDirectoryRole | Where-Object {$_.displayName -eq 'User Account Administrator'}
# Get the 'Company Administrator' Role reference in Azure AD
$roleCA = Get-AzureADDirectoryRole | Where-Object {$_.displayName -eq 'Company Administrator'}

# Get the ObjectId of the Terraform Service Principal
$tf_sp = Get-AzureADServicePrincipal -All $true | Where-Object {$_.displayName -eq $TfSpName}

# Checking/Setting membership to User Account Administrator Role
$isUAAMember = Get-AzureADDirectoryRoleMember -ObjectId $roleUAA.ObjectId | Where-Object {$_.displayName -eq $tf_sp.DisplayName}
if($isUAAMember -eq $null) {
  Add-AzureADDirectoryRoleMember -ObjectId $roleUAA.ObjectId -RefObjectId $tf_sp.ObjectId }

# Checking/Setting membership to Company Administrator Role
$isCAMember = Get-AzureADDirectoryRoleMember -ObjectId $roleCA.ObjectId | Where-Object {$_.displayName -eq $tf_sp.DisplayName}
if($isCAMember -eq $null) {
  Add-AzureADDirectoryRoleMember -ObjectId $roleCA.ObjectId -RefObjectId $tf_sp.ObjectId }