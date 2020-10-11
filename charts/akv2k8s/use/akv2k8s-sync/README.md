# AKV2K8S Secret Synchronization Helm Chart

This chart will create the instance of a CRD of type ```AKVS``` (```AzureKeyVaultSecret```) to **synchronize** the value of an object pulled from Azure Key Vault (key/certificate/secret) into a Kubernetes secret resource in a Kubernetes cluster.

For more information see the main GitHub repository at https://github.com/SparebankenVest/azure-key-vault-to-kubernetes.

## Requirements
To operate, it is required to:
* Have deployed and operational both the CRD and the (synchornization) Controller pieces of [akv2k8s](https://akv2k8s.io/installation/)

* To have referenced the generated Kubernetes secret in a pod/deployment, as explained in Kubernetes offcial documentation [Using secrets](https://kubernetes.io/docs/concepts/configuration/secret/#using-secrets)

## Configuration

The following table lists configurable parameters of the ```akv2k8s-inject``` chart and their default values.

|               Parameter                |                Description                   |                  Default                 |
| -------------------------------------- | -------------------------------------------- | -----------------------------------------|
| keyvaultName                           | Name of the Azure Key Vault to pull secrets from.             | None                 |
| keyvaultObjectName                     | Name of the Key Vault object to use.      | None         |
| keyvaultObjectType                     | Type of the Key Vault object to use. Possible values: ```key``` / ```secret``` / ```certificate```.     | ```secret``` |

**Note**: The AKVS object created will have the  name of the Helm chart release that created it.