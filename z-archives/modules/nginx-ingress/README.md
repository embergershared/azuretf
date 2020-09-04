# Terraform Kubernetes Ingress Nginx Controller Module

## Description
This Terraform module: 
- Deploys a Kubernetes Ingress Controller in a Kubernetes Cluster,
- Creates a test service for generic cloud deployments
mimicking this installation guide: https://kubernetes.github.io/ingress-nginx/deploy/ 

The Ingress Controller installed is "ingress-nginx": https://kubernetes.github.io/ingress-nginx/

## Requirements
The module requires:
- the Kubernetes Terraform provider to be appropriately setup. (documentation is here: https://www.terraform.io/docs/providers/kubernetes/guides/getting-started.html).
- Terraform v0.12 or higher.


# Example Usage
```
module nginx-ingress-controller {
    source = "../modules/nginx-ingress"
}
```

## Module's variables

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| source | Relative path to the module directory | string | none | yes |
| image | Docker image for the nginx-ingress-controller | string | quay.io/kubernetes-ingress-controller/nginx-ingress-controller | no |
| image_version | Docker image version for the nginx-ingress-controller | string | 0.30.0 | no |
| namespace | Namespace to deploy Nginx Ingress controller into | string | ingress-nginx | no |
| probe_port | Health/Prometheus default probe port | integer | 10254 | no |

## Outputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| None ||||||


## Verify the install
Run this command to check its deployment:
```
kubectl get pods --all-namespaces -l app.kubernetes.io/name=ingress-nginx --watch
```

# Reference
This module performs the equivalent of these 2 commands:
```
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/nginx-0.30.0/deploy/static/mandatory.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/nginx-0.30.0/deploy/static/provider/cloud-generic.yaml
```
