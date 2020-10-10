# AKV2K8S Secret Injection Helm Chart

This chart will create the instance of a CRD of type ```AKVS``` (AzureKeyVaultSecret) to inject the value of an object pulled from Azure Key Vault (key/certificate/secret) into a Kubernetes pod/deployment as an Environment Variable, when appropriately configured.

For more information see the main GitHub repository at https://github.com/SparebankenVest/azure-key-vault-to-kubernetes.

## Requirements
To operate, it is required to have deployed and operational the CRD and the Environment Injector pieces of [akv2k8s](https://akv2k8s.io/installation/)

The namespace in which the pod/deployment are created must have the label:
```
  labels:
    azure-key-vault-env-injection: enabled
```

To inject a value, it is required to reference it as it is explained in the Injection tutorials that are here: [Inject Secret](https://akv2k8s.io/tutorials/env-injection/1-secret/), [Inject Certificate](https://akv2k8s.io/tutorials/env-injection/2-certificate/), [Inject Signing Key](https://akv2k8s.io/tutorials/env-injection/3-signing-key/) & [Inject PFX Certificate](https://akv2k8s.io/tutorials/env-injection/5-pfx-certificate/)

## Configuration

The following table lists configurable parameters of the azure-key-vault-controller chart and their default values.

|               Parameter                |                Description                   |                  Default                 |
| -------------------------------------- | -------------------------------------------- | -----------------------------------------|
| keyvaultName                           | Name of the Azure Key Vault to pull secrets from.             | None                 |
| keyvaultObjectName                     | Name of the Key Vault Object to use.      | None         |
| keyvaultObjectType                     | Type of the Key Vault Object to use (key/secret/certificate).     | secret |

**Note**: The AKVS object created will have the same name than the Helm chart release that created it.