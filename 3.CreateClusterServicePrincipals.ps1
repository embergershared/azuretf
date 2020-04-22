#   Ref: https://docs.microsoft.com/en-us/azure/aks/kubernetes-service-principal
#
#   Create with az CLI the Service Principals for the AKS cluster:
$subscription_id = "sub"
$subscription_nickname = "subnickname"
$account_nickname="accnickname"
$kvName="keyvault"

# Do not touch these automatic namings:
$aksclusterbasename = "${subscription_nickname}-${account_nickname}-AKS-Cluster"
$aksclusterspname = "${aksclusterbasename}-SP"
$winnodesadmin="${aksclusterbasename}-WinAdmin"
$aadservername = "${aksclusterbasename}-AAD-Server"
$aadclientname = "${aksclusterbasename}-AAD-Client"

# Process Data
$scriptName = $MyInvocation.MyCommand.Name
$Time = Get-Date
$expDate = $(Get-Date -Date $Time.AddDays(364).ToUniversalTime() -Format "yyyy-MM-ddTHH:mm:ssZ") # 2020-04-05T17:15:13Z
$actDate = $(Get-Date -Date $Time.ToUniversalTime() -Format "yyyy-MM-ddTHH:mm:ssZ")

# Login to Azure
az login
# Set the subscription
az account set --subscription $subscription_id

#  ======  Create AKS Service Principal and Register it in Key Vault  ======
# 1.Check if the SP already exists
$existing_app_id=$(az ad sp list --display-name $aksclusterspname --query [].appId `
                                --filter "DisplayName eq '$aksclusterspname'" -o tsv)
$appExists = !($null -eq $existing_app_id)

if ($appExists) {
    # Refresh the AKS Service Principal secret
    $appId = $existing_app_id
    $appPwd = $(az ad sp credential reset --name $appId --query password -o tsv)
} else {
    # Create the AKS Service Principal
    $app = $(az ad sp create-for-rbac --skip-assignment --name $aksclusterspname `
                                --query '[appId, password]' -o tsv)
    $appId = $app[0]
    $appPwd = $app[1]
}

# 2. Update values in Azure Key Vault
az keyvault secret set --name ("${aksclusterspname}-id").ToLower() `
        --vault-name $kvName --value $appId --description $aksclusterspname `
        --expires $expDate --not-before $actDate --tags CreatedBy=$scriptName `
        --query id -o tsv

az keyvault secret set --name ("${aksclusterspname}-secret").ToLower() `
        --vault-name $kvName --value $appPwd --description $aksclusterspname `
        --expires $expDate --not-before $actDate --tags CreatedBy="$scriptName" `
        --query id -o tsv

# 3. Create/Update values for Windows Nodes
az keyvault secret set --name ("${winnodesadmin}-user").ToLower() `
        --vault-name $kvName --value "azureuser" --description $winnodesadmin `
        --expires $expDate --not-before $actDate --tags CreatedBy="$scriptName" `
        --query id -o tsv

$random = $(-join ((48..57) + (65..90) + (97..122) | Get-Random -Count 14 | % {[char]$_}))
az keyvault secret set --name ("${winnodesadmin}-pwd").ToLower() `
        --vault-name $kvName --value $random --description $winnodesadmin `
        --expires $expDate --not-before $actDate --tags CreatedBy=$scriptName `
        --query id -o tsv


#  ======  Create Azure AD Service Principals and Register them in Key Vault  ======
#   Reference: https://docs.microsoft.com/en-us/azure/aks/azure-ad-integration-cli
#
#   1. Azure AD Server App: (acts like an endpoint for identity requests)
#       a. Check/Create the AAD Server App + its SP:
$existing_aadserver_app_id=$(az ad sp list --display-name $aadservername --query [].appId -o tsv)
$aadserver_appExists = !($null -eq $existing_aadserver_app_id)
if ($aadserver_appExists) {
    $serverApplicationId = $existing_aadserver_app_id
} else {
#       Create the AAD Server Service Principal
    $serverApplicationId = $(az ad app create --display-name $aadservername `
                                --identifier-uris "https://${aadservername}" `
                                --query appId -o tsv)
    az ad app update --id $serverApplicationId --set groupMembershipClaims=All
    az ad sp create --id $serverApplicationId
}
#       b. Refresh the AAD Server Service Principal secret
$serverApplicationSecret = $(az ad sp credential reset --name $serverApplicationId `
                                --credential-description "${aadservername}-Password" `
                                --query password -o tsv) # --years: default is 1 year

#       c. Add AAD Server permissions to Read directory data permission + Sign in and read user profile
az ad app permission add --id $serverApplicationId `
                        --api 00000003-0000-0000-c000-000000000000 `
                        --api-permissions e1fe6dd8-ba31-4d61-89e7-88639da4683d=Scope `
                                        06da0dbc-49e2-44d2-8312-53f166ab848a=Scope `
                                        7ab1d382-f21e-4acd-a863-ba3e13f7da61=Role
#
#       d. Grant AAD Server the permission added previously
az ad app permission grant --id $serverApplicationId `
                        --api 00000003-0000-0000-c000-000000000000
az ad app permission admin-consent --id  $serverApplicationId
#
#       e. Update values in Azure Key Vault
az keyvault secret set --name ("${aadservername}-id").ToLower() `
        --vault-name $kvName --value $serverApplicationId --description $aadservername `
        --expires $expDate --not-before $actDate --tags CreatedBy="$scriptName" `
        --query id -o tsv

az keyvault secret set --name ("${aadservername}-secret").ToLower() `
        --vault-name $kvName --value $serverApplicationSecret --description $aadservername `
        --expires $expDate --not-before $actDate --tags CreatedBy="$scriptName" `
        --query id -o tsv
#
#
#   2. Azure AD Client App: (used when users logon to AKS with kubectl)
#       a. Check/Create the AAD Client SP
$existing_aadclient_app_id=$(az ad sp list --display-name $aadclientname --query [].appId -o tsv)
$aadclient_appExists = !($null -eq $existing_aadclient_app_id)
if ($aadclient_appExists) {
    $clientApplicationId = $existing_aadclient_app_id
} else {
#       Create the AAD Client Service Principal
    $clientApplicationId = $(az ad app create --display-name $aadclientname `
                                --reply-urls    "https://${aadclientname}" `
                                                "https://afd.hosting.portal.azure.net/monitoring/Content/iframe/infrainsights.app/web/base-libs/auth/auth.html" `
                                                "https://monitoring.hosting.portal.azure.net/monitoring/Content/iframe/infrainsights.app/web/base-libs/auth/auth.html" `
                                --native-app `
                                --query appId -o tsv)
    az ad sp create --id $clientApplicationId
}

#       b. Get the oAuth2 ID of the AAD Server App
$oAuthPermissionId=$(az ad app show --id $serverApplicationId --query "oauth2Permissions[0].id" -o tsv)
#
#       c. Add permission to Client App to use oAuth2 server communication flow
az ad app permission add --id $clientApplicationId --api $serverApplicationId `
                                --api-permissions ${oAuthPermissionId}=Scope
az ad app permission grant --id $clientApplicationId --api $serverApplicationId
#
#       d. Update value in Azure Key Vault
az keyvault secret set --name ("${aadclientname}-id").ToLower() `
        --vault-name $kvName --value $clientApplicationId --description $aadclientname `
        --expires $expDate --not-before $actDate --tags CreatedBy="$scriptName" `
        --query id -o tsv


#   3. Give AKS Cluster Service Principal Reader's role on the ACR
$sharedsvcrg=$(az keyvault show -n $kvName --query resourceGroup -o tsv)
$acrid=$(az acr list -g $sharedsvcrg --query [].id -o tsv)
az role assignment create --assignee $serverApplicationId --scope $acrid --role Reader