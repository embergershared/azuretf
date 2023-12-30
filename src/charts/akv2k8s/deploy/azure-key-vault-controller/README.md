# Azure Key Vault Controller Helm Chart

>**Deprecated - This Chart is deprecated in favor of the new [Akv2k8s Helm 3 Chart](../akv2k8s). Last supported version of the controller was `1.1.x`. This chart will be patched with any changes to controller versions <= `1.1.x`, but new controller versions (>= 1.2.x) will only be added to the new [Akv2k8s Helm 3 Chart](../akv2k8s).**

---

This chart will install a Kubernetes controller and a Custom Resource Definition (`AzureKeyVaultSecret`), that together enable secrets from Azure Key Vault to be stored as Kubernetes native `Secret` resources.

For more information see the main GitHub repository at https://github.com/SparebankenVest/azure-key-vault-to-kubernetes.

## Installation

See the documentation for installation instructions: https://akv2k8s.io/installation/

## The AzureKeyVaultSecret CRD

We have removed the CRD from the Helm Chart and this must be manually installed/updated prior to installing the chart:

```
kubectl apply -f https://raw.githubusercontent.com/sparebankenvest/azure-key-vault-to-kubernetes/crd-{{ version }}/crds/AzureKeyVaultSecret.yaml
```

To use the latest CRD, run:

```
kubectl apply -f https://raw.githubusercontent.com/sparebankenvest/azure-key-vault-to-kubernetes/crd-1.1.0/crds/AzureKeyVaultSecret.yaml
```

## Configuration

The following table lists configurable parameters of the azure-key-vault-controller chart and their default values.

|               Parameter                |                Description                   |                  Default                 |
| -------------------------------------- | -------------------------------------------- | -----------------------------------------|
|env                                     |aditional env vars to send to pod             |{}                                        |
|image.repository                        |image repo that contains the controller image | spvest/azure-keyvault-controller         |
|image.tag                               |image tag|1.1.0|
|image.pullPolicy                        |pull policy | IfNotPresent |
|installCrd                              |install custom resource definition           |true                                      |
|keyVault.customAuth.enabled             |if custom auth is enabled | false |
|keyVault.polling.normalInterval         |interval to wait before polling azure key vault for secret updates | 1m |
|keyVault.polling.failureInterval        |interval to wait when polling has failed `failureAttempts` before polling azure key vault for secret updates | 5m |
|keyVault.polling.failureAttempts        |number of times to allow secret updates to fail before applying `failureInterval` | 5 |
|labels                                  |any additional labels | {}
|logFormat                               |log format - fmt or json | fmt                   |
|logLevel                                |log level | info |
|podLabels                               |any additional labels | {}
