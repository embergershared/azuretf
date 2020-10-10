# AKV2K8S Secret Synchronization Helm Chart

This chart will create the instance of a CRD of type ```AKVS``` (AzureKeyVaultSecret) to synchronize an object pulled from Azure Key Vault (key/certificate/secret) for which the value can be injected in a pod/deployment as an Environment Variable, if appropriately configured.

For more information see the main GitHub repository at https://github.com/SparebankenVest/azure-key-vault-to-kubernetes.

## Requirements
To operate, it is required to have deployed and operational the CRD and the Environment Injector pieces of [akv2k8s](https://akv2k8s.io/installation/)

## Configuration

The following table lists configurable parameters of the azure-key-vault-controller chart and their default values.

|               Parameter                |                Description                   |                  Default                 |
| -------------------------------------- | -------------------------------------------- | -----------------------------------------|
| keyvaultName                           | Name of the Azure Key Vault to pull secrets from.             | None                 |
| keyvaultObjectName                     | Name of the Key Vault Object to use.      | None         |
| keyvaultObjectType                     | Type of the Key Vault Object to use (key/secret/certificate).     | secret |