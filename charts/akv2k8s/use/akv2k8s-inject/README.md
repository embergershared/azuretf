# AKV2K8S Secret Injection Helm Chart

This chart will create the instance of a CRD of type ```AKVS``` (```AzureKeyVaultSecret```) to **inject** the value of an object pulled from Azure Key Vault (key/certificate/secret) into a Kubernetes pod/deployment as an Environment Variable, when appropriately configured.

For more information see the main GitHub repository at https://github.com/SparebankenVest/azure-key-vault-to-kubernetes.

## Requirements
To operate, it is required to:
* Have deployed and operational both the CRD and the Environment Injector pieces of [akv2k8s](https://akv2k8s.io/installation/)

* The namespace in which the pod/deployment are created must have the label:
```
  labels:
    azure-key-vault-env-injection: enabled
```

* To have referenced the value to inject in the pod/deployment, as explained in the Injection tutorials:
  * [Inject Secret](https://akv2k8s.io/tutorials/env-injection/1-secret/),
  * [Inject Certificate](https://akv2k8s.io/tutorials/env-injection/2-certificate/),
  * [Inject Signing Key](https://akv2k8s.io/tutorials/env-injection/3-signing-key/) & 
  * [Inject PFX Certificate](https://akv2k8s.io/tutorials/env-injection/5-pfx-certificate/)

## Configuration

The following table lists configurable parameters of the ```akv2k8s-inject``` chart and their default values.

|               Parameter                |                Description                   |                  Default                 |
| -------------------------------------- | -------------------------------------------- | -----------------------------------------|
| keyvaultName                           | Name of the Azure Key Vault to pull secrets from.             | None                 |
| keyvaultObjectName                     | Name of the Key Vault object to use.      | None         |
| keyvaultObjectType                     | Type of the Key Vault object to use. Possible values: ```key``` / ```secret``` / ```certificate```.     | ```secret``` |

**Note**: The AKVS object created will have the  name of the Helm chart release that created it.