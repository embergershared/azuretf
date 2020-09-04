# Azure with Terraform
This repository is aimed at sharing the code created in various contexts to deploy Azure resources and infrastructures, using (HashiCorp) Terraform.

It is provided as is, with no support or warranty, but this code is used in real scenarios for real customers/workloads.

# Infrastructure as Code
## Challenges
Using IaC based on Terraform for almost 2 years now, I met 4 challenges I try to address here to help:
1. **Start locally, but be ready for Pipelines** deployment later, as easily as possible,
2. **Separate completely the Infrastructure Plans from their Instances Values** (including defaults, and instances' Terraform backend state storage),
3. **Set a Variable value once** for all the instances that need it and never duplicate it,
4. Acknowledge all **deployments happen in layers/steps**:
    - **A Landing zone (Hub)**:    
    Networking, Policies, Egress & Ingress Firewall, Application Gateway, Key Vault, VPN, Jumpboxes, etc.
    - **Multiple Workloads (Spokes)**:    
    Virtual Machines, Storage, AI models, Databases, Functions, Containers instances, etc.    
    The main idea is to deploy/remove them as plug-in/plug-out pieces.

With time, these challenges were growing, using Jenkins, Azure DevOps, bash and PowerShell scripts, Terraform local, Cloud and Enterprise, and I came to the following solution:

## Offered solution
To solve these challenges, I created a PowerShell script, and a structured organisation of all the pieces. The script does these main things:
* merges all the Terraform elements ```*.tf``` files in a folder,
* searches for the values in ```*.json``` files,
* creates the Environment variables for the Variable/Values pairs for this execution,
* runs a Terraform command (default is "Apply"),
* cleans everything after execution.

## Benefits



# Usage
## General


## Parameters


## Examples


# Q&A
* Why JSON for the values and not Terraform ```(auto.)tfvars.tf```?
> JSON is system independent and can easily be manipulated by PowerShell, bash (or other shells) and CD Pipelines. Using JSON helps to be ready for Pipelines transition.
* Why set defaults values in JSON and not in the Terraform ```variables*.tf``` files?
> When set in a Terraform variable declaration (```variable name { default = "default value" } ```), the default value is a value put in the Plan. It defeats the approach of completely separating Plans from Values. It makes the default values management difficult, especially when these values are different, for example between a types of environments.
* Why source control the JSON files (except secrets)?
> A major problem we faced in a project using Terraform Enterprise, was that the values are not versioned control in Terraform Enterprise. So, when a value is changed in the UI, there is no way to track it. Source controlling teh JSON files allows to track values changes AND use branching for Infrastructure Instances changes.