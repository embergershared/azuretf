# AKV2K8S Secret Synchronization Helm Chart

This chart will create the instance of a CRD of type ```AKVS``` (```AzureKeyVaultSecret```) to **synchronize** the value of an object pulled from Azure Key Vault (key/certificate/secret) into a Kubernetes secret resource in a Kubernetes cluster.

For more information see the main GitHub repository at https://github.com/SparebankenVest/azure-key-vault-to-kubernetes.

## Requirements
To operate, it is required to:
* Have deployed and operational both the CRD and the (synchornization) Controller pieces of [akv2k8s](https://akv2k8s.io/installation/)

* Have referenced the generated Kubernetes secret in a pod/deployment, as explained in Kubernetes offcial documentation [Using secrets](https://kubernetes.io/docs/concepts/configuration/secret/#using-secrets)

## Configuration

The following table lists configurable parameters of the ```akv2k8s-inject``` chart and their default values.

|Parameter|Description|Mandatory|Default|
| ---------------- | --------------------- | -------------- | ----------------------- |
| keyvaultName| Name of the Azure Key Vault to pull secrets from.| Yes | None|
| keyvaultObjectName| Name of the Key Vault object to use.| Yes | None|
| keyvaultObjectType| Type of the Key Vault object to use. Possible values: ```key``` / ```secret``` / ```certificate```.     | No | ```secret``` |
| k8sSecretName | Name of the Kubernetes secret to create. | Yes | None |
| keyType | Describe of the Opaque to create is of 1 value or multiple value. Every value, except ```mono``` will create a multiple ```Opaque``` secret. | No | ```mono``` |
| secretKey | Key in the Kubernetes secret | No | ```secret-key``` |
| contentType| If the keyType **is not** ```mono``` then the type of contentType will be used to deserialize the key/pairs. Allowed values are ```application/x-json``` or ```application/x-yaml```. If keyType is ```mono```, contentType is not required. | No | ```application/x-json``` |

**Note**: The AKVS object created will have the name of the Helm chart release that created it.