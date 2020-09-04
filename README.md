# Azure with Terraform
This repository is aimed at sharing the code created in various contexts to deploy Azure resources and infrastructures, using (HashiCorp) Terraform.

It is provided as is, with no support or warranty, but this code is used in real scenarios for real customers/workloads.

# Infrastructure as Code
## Challenges
Using IaC based on Terraform for almost 2 years now, I met 4 challenges I try to address here to help:
1. Start locally, but being ready for a later Pipelines deployment as easily as possible,
2. Separate completely the Infrastructure Plans from their Instances Values (including defaults, and instances' Terraform backend state storage),
3. Set a Variable value once for all the instances that need it and never duplicate it,
4. Acknowledge all deployments happen in layers/steps:
  * A Landing zone (Hub): 
  Networking, Policies, Egress & Ingress Firewall, Application Gateway, Key Vault, VPN, Jumpboxes, etc.
  * Multiple Workloads (Spokes):
  Virtual Machines, Storage, AI models, Databases, Functions, Containers instances, etc. The main idea is to separate them as plug-in/plug-out pieces,

With time, these challenges were growing, using Jenkins, Azure DevOps, bash and PowerShell scripts, Terraform local, Cloud and Enterprise, and I came to the following solution:

## Offered solution
To solve all these, I created a PowerShell script that merges all the required elements to run a plan. 