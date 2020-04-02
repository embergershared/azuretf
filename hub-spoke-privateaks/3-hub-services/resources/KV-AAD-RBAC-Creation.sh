#   Reference: https://docs.microsoft.com/en-us/azure/aks/azure-ad-integration-cli
#
#   0. Set variables for the script
aksTier="Private-AKS"
kvName="Hub-KeyVault-KV"
expDate=$(date --utc +%Y-%m-%d'T'%H:%M:%S'Z' -d "+364 days")
actDate=$(date --utc +%Y-%m-%d'T'%H:%M:%S'Z') # -d "-1 minutes")
#
#   1. Azure AD Server App: (acts like an endpoint for identity requests)
#       a. Create the AAD Server App + its SP:
serverApplicationId=$(az ad app create --display-name "${aksTier}-AAD-Server" --identifier-uris "https://${aksTier}-AAD-Server" --query appId -o tsv)
az ad app update --id $serverApplicationId --set groupMembershipClaims=All
az ad sp create --id $serverApplicationId
serverApplicationSecret=$(az ad sp credential reset --name $serverApplicationId --query password -o tsv) # --years: default is 1 year
#
#       b. Add AAD Server permissions to Read directory data permission + Sign in and read user profile
az ad app permission add --id $serverApplicationId --api 00000003-0000-0000-c000-000000000000 --api-permissions e1fe6dd8-ba31-4d61-89e7-88639da4683d=Scope 06da0dbc-49e2-44d2-8312-53f166ab848a=Scope 7ab1d382-f21e-4acd-a863-ba3e13f7da61=Role
#
#       c. Grant AAD Server the permission added previously
az ad app permission grant --id $serverApplicationId --api 00000003-0000-0000-c000-000000000000
az ad app permission admin-consent --id  $serverApplicationId
#
#       d. Update values in Azure Key Vault
az keyvault secret set --name "private-aks-aad-server-id" --vault-name "${kvName}" \
        --value $serverApplicationId --description "${aksTier}-AAD-Server" \
        --expires $expDate --not-before $actDate --tags CreatedBy="KV-AAD-RBAC-Creation.sh" \
        --query id -o tsv

az keyvault secret set --name "private-aks-aad-server-secret" --vault-name "${kvName}" \
        --value $serverApplicationSecret --description "${aksTier}-AAD-Server" \
        --expires $expDate --not-before $actDate --tags CreatedBy="KV-AAD-RBAC-Creation.sh" \
        --query id -o tsv
#
#   2. Azure AD Client App: (used when users logs to AKS with kubectl)
#       a. Create the AAD Client App + its SP:
clientApplicationId=$(az ad app create --display-name "${aksTier}-AAD-Client" --native-app --reply-urls "https://${aksTier}-AAD-Client" --query appId -o tsv)
az ad sp create --id $clientApplicationId
#
#       b. Get the oAuth2 ID of the AAD Server App
oAuthPermissionId=$(az ad app show --id $serverApplicationId --query "oauth2Permissions[0].id" -o tsv)
#
#       c. Add permission to Client App to use oAuth2 server communication flow
az ad app permission add --id $clientApplicationId --api $serverApplicationId --api-permissions ${oAuthPermissionId}=Scope
az ad app permission grant --id $clientApplicationId --api $serverApplicationId
#
#       d. Update values in Azure Key Vault
az keyvault secret set --name "private-aks-aad-client-id" --vault-name "${kvName}" \
        --value $clientApplicationId --description "${aksTier}-AAD-Client" \
        --expires $expDate --not-before $actDate --tags CreatedBy="KV-AAD-RBAC-Creation.sh" \
        --query id -o tsv
