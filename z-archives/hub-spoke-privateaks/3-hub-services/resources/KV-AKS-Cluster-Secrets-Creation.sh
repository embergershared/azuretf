#   Ref: https://docs.microsoft.com/en-us/azure/aks/kubernetes-service-principal
#
#   Create with az CLI the Service Principal for the cluster:
spname="Spoke-Private-AKS-Cluster"
spUrl="http://487c38.hubspoke-privaks-dns.canadacentral.cloudapp.azure.com"

winnodesadmin="Private-AKS-Cluster-WinNodesAdmin"
kvName="Hub-KeyVault-KV"
expDate=$(date --utc +%Y-%m-%d'T'%H:%M:%S'Z' -d "+364 days")
actDate=$(date --utc +%Y-%m-%d'T'%H:%M:%S'Z') # -d "-1 minutes")

#  Uncomment either:    1a to create the Cluster Service Principal or
#                       1b with the appropriate values to rotate the secret
#       1a. Create the Service Principal
#appPwd=$(az ad sp create-for-rbac --skip-assignment --name $spname --query password -o tsv) # --years: default is 1 year
#appId=$(az ad sp list --display-name $spname --query [].appId -o tsv)

#       1b. Rotate secret of the Service Principal
#appId="ABC"
#appPwd=$(az ad sp credential reset --name $appId --query password -o tsv)

#      2. Update values in Azure Key Vault
az keyvault secret set --name "private-aks-cluster-sp-id" \
        --vault-name "${kvName}" --value $appId --description $spname \
        --expires $expDate --not-before $actDate --tags CreatedBy="KV-AKS-Cluster-Secrets-Creation.sh" \
        --query id -o tsv

az keyvault secret set --name "private-aks-cluster-sp-secret" \
        --vault-name "${kvName}" --value $appPwd --description $spname \
        --expires $expDate --not-before $actDate --tags CreatedBy="KV-AKS-Cluster-Secrets-Creation.sh" \
        --query id -o tsv

#       3. Create/Update values for Windows Nodes
az keyvault secret set --name "private-aks-winnodes-admin-user" \
        --vault-name "${kvName}" --value "azureuser" --description $winnodesadmin \
        --not-before $actDate --tags CreatedBy="KV-AKS-Cluster-Secrets-Creation.sh" \
        --query id -o tsv

az keyvault secret set --name "private-aks-winnodes-admin-pwd" \
        --vault-name "${kvName}" --value "z92xI7Rj45b9g4h7" --description $winnodesadmin \
        --not-before $actDate --tags CreatedBy="KV-AKS-Cluster-Secrets-Creation.sh" \
        --query id -o tsv