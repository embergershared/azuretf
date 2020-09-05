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
To solve these challenges, I created a PowerShell script, and a structured organization of all the pieces.    
The script does these main things:
* Merges all the Terraform files ```*.tf``` in one folder,
* Searches for the values in ```*.json``` files,
* Creates the Environment variables for the Variable/Value pairs for this execution,
* Runs the Terraform command (default is "Apply") in the folder,
* Cleans everything after execution.

## Benefits
This solution addresses the challenges in these ways:
* The Plans do not have any data or values in them:    
They are managed independently from the instances that are deployed from them.    
They mainly consist of:
    * The ```main.tf``` file that describes the resources and modules to deploy the infrastructure,
    * 1/n ```variables_*.tf``` files that declares the variables needed for the ```main.tf``` file execution.    
    Separating in multiple files the variables declaration:
      * Prepares for Variables' Groups in Pipelines,
      * Indicates the JSON values files required to execute this plan,
      * Unfortunately, requires some copy/paste (that could be improved with a manifest).
* Creating multiple instances of a same Plan is REALLY easy, possible and manageable:    
    * Run the script pointing on the same Plan and on a different Values folder.    
    * Things that are common will be the same and differences will be different.
* When a Variable Value is set in its JSON file, the script will find it and use it anytime needed for the plans that use it (by their inclusion of the respective ```variables_.tf```).
* To transfer these plans in a Pipeline, put the Plans in the repository and choose the best method for the variables values (Variables Groups, Terraform Cloud/Enterprise UI, Terraform API calls, in memory sourcing within the agent with ```TF_VAR_```, generate ```auto.tfvars.tf``` files as artifacts). What matters is that the exact list of variables and values to provide for a plan is declared in the plan's folder.
* The Terraform backend settings to store the state of the infrastructure instance are set in a ```state_*,tf``` file located in the Values folder. This is because each state is unique for each instance. The script merging all the required ```*.tf``` files in the Values folder before execution, creates the consistency of the full plan.    
Additionnally, the Terraform backend settings have to be hard-coded, they cannot reference variables. So, managing them as Values makes a lot of sense.

# Usage
## General
The general use is simple:
* on a Windows machine with PowerShell,
* Go in the folder that has the script file ```tfplan.ps1``` (in the repo: ```/tf-plans```)

Execute the script with the Plan and Values folders as parameters:    
```.\tfplan.ps1 -MainTfPath .\1-hub\3-sharedsvc\ -ValuesTfPath ..\subscriptions\demo\1-hub\3-sharedsvc\```

A typical output will look like this:
```
Starting "tfplan.ps1" with parameters: Command="Execute", Main=".\1-hub\3-sharedsvc\", Values="..\subscriptions\demo\1-hub\3-sharedsvc\"
Plan   path is: \GitHub\azuretf\tf-plans\1-hub\3-sharedsvc\
Values path is: \GitHub\azuretf\subscriptions\demo\1-hub\3-sharedsvc\
Copied 3 "srcd-" files in Values Path.
Sourcing Variables values from Terraform Variables files names (variables_).
Processed 3 JSON files and 12 variables.
Executing Terraform...
        >>> Terraform messages and processing <<<
Press Enter to finish script...
Finished Terraform.
Removed 7 "Env:TF_VAR_*" Environment variables.
Deleted 3 "srcd-" files from Values Path.
Finished "tfplan.ps1" script
```

## Parameters
| Parameter | Description | Mandatory |
|-----------|-------------|-----------|
| ```-MainTfPath``` | Used to give the argument of the Terraform Plan path | Yes |
| ```-ValuesTfPath``` | Used to give the argument of the Terraform Values path | Yes |
| ```-b``` | Generates the full build in the Values folder. The script stops and it is possible to execute Terraform commands manually, like ```terraform state list```. Once done, execute ```Pop-Location``` to return to the script path.    **Note**: the environment and copied files are not cleaned. | No |
| ```-i``` | Executes a ```terraform init```    on the Plan + Values build. | No |
| ```-d``` | Executes a ```terraform destroy``` on the Plan + Values build. | No |
| ```-p``` | Executes a ```terraform plan```    on the Plan + Values build. | No |

Note: Except for the ```-b``` argument, all other arguments will clean the Values folder and Environment variables created.

## Get started
To get started with the provided plans:
1. Create an Azure Service Principal (Portal, azure CLI, azure PowerShell, etc.),
2. Note the following data: *TenantId*, *SubscriptionId*, *AppId*, *AppSecret*,
3. Give this Service Principal the appropriate permissions (usually Contributor on a ubscription),
4. Fill-in *TenantId*, *SubscriptionId*, *AppId* values in the file ``\subscriptions\demo\demo_tfspn.json```
5. Modify the other values in ```demo_tfspn.json``` to your context,
6. Fill-in *AppSecret* value in the file ```\subscriptions\demo\demo_tfspn_secret.json```
7. Check that the file ```demo_tfspn_secret.json``` will not be checked-in your repo,
8. Save the changes,
9. Follow the steps for the first plan:    
    The first plan ```\tf-plans\1-hub\1-terraform``` creates the resource group, storage account and container to store all the following Terraform states.    
    To set it up:
    * Execute the plan:    
    ```.\tfplan.ps1 -MainTfPath .\1-hub\1-terraform\ -ValuesTfPath ..\subscriptions\demo\1-hub\1-terraform\```,
    * It will create the Resources,
    * Once done, uncomment the lines 4 to 12 in the file ```\subscriptions\demo\1-hub\1-terraform\state_hub-terraform.tf``` (remove the starting ```# ```),
    * Fill in the values for *subscription_id*, *resource_group_name* and *storage_account_name* in the file ```state_hub-terraform.tf```,
    * Save the changes,
    * Execute the plan a second time, with the ```-i``` argument:    
    ```.\tfplan.ps1 -MainTfPath .\1-hub\1-terraform\ -ValuesTfPath ..\subscriptions\demo\1-hub\1-terraform\ -i```,
    * Answer ```yes``` to move from local to remote backend,
    * You're started.


## Comments
* By default, the script launches a ```terraform apply```. It saves time from the sequence ```terraform plan``` then ```terraform apply```, and maintain execution consistency.    
To discard changes, just hit enter at prompt.    
To apply changes, type ```yes``` and hit enter.    
* The Plans provided leverage the [Azure Cloud Adoption Framework](https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/), like the [Naming and Tagging](https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/naming-and-tagging) and the [Hub & Spoke architecture](https://docs.microsoft.com/en-us/azure/architecture/reference-architectures/hybrid-networking/hub-spoke). These may not fit your deployments and conventions. Please, adapt to your need.

## Conventions
* The JSON file with the values for a set of variables must have the same name pattern:
    * the values for ```variables_tfspn.tf``` must be in a JSON file named by this pattern: ```*tfspn*.json```,
    * the values can be split in multiples files, like ```tfspn.json``` and ```tfspn_secret.json``` to prevent secrets commit in the repo,
* The script looks for file matching the variables going up in the Values' folder structure:
    * It starts in the Value folder given as script argument,
      * If no JSON files match the pattern,
      * It goes up one folder, then search again until a matching JSON file is found,
      * Once found at 1 level, it stops here,
    * Once all the JSON files for the required variables have been found, the values are processed in reverse order of their discovery: It ensures that the values set the closest to the instance will be the ones applied.
    * It is allows to override some defaults values specifically for in 1 instance deployment.
* To ensure the processing of the default values, an empty variables Terraform file is created in the Plans folder. It ensures the default Values JSON file will be processed.    
An example can be found with this file: ```\tf-plans\3-aks\2-cluster\variables_aks-defaults.tf``` it is empty, but it allows this values file to be processed: ```\subscriptions\demo\3-aks\demo_aks-defaults.json```

# Q&A
Why JSON for the values and not Terraform ```(auto.)tfvars.tf```?
> JSON is system independent and can easily be manipulated by PowerShell, bash (or other shells) and CD Pipelines. Using JSON helps to be ready for Pipelines transition.    

Why set defaults values in JSON and not in the Terraform ```variables_*.tf``` files?
> When declaring a variable in Terraform (```variable name { default = "default value" } ```), a "default value" can be set. But this declaration is part of the Plan, it is within the Plan. It defeats the approach of completely separating Plans and Values. It also makes the default values management difficult, especially when the default values are different from an environment type to another.

Why source control the Values' JSON files (except secrets)?    
> A major problem we faced in a project using Terraform Enterprise was that the values are not versioned controlled in Terraform Enterprise. When the value of a variable in a workspace is changed with the UI, there is no way to track it. Source controlling the JSON files allows to track values changes AND use branching for all changes (Plans and/or Values). In the mentioned project, we pushed through the Pipeline the variables values to be used by the workspace before all the Plans execution leveraging curl API calls to set the Terraform Enterprise workspace variables values from our repo (except secrets that were injected by Jenkins).    

Why use the Environment Variables and not a file?
> Using the ```TF_VAR_``` sourcing approach as Environment Variables on the host is more secure than a file with the values. It is mimicking the short lived pipelines agents. If any hang or crash happen, no values' data is persisted. Values are in memory, just for the time they are needed.    

Why use 1 ```main_*.tf``` and multiple ```variables_*.tf``` files?
> The multiple variables files allows to see right away which variables are needed for a plan. It eases the use of Variable Groups in Azure DevOps.    
> The use of 1 main Terraform files (instead of splitted main.tf for the Plan), allows IntelliSense in the IDE to reference and debug more easily resources while building the plan.

What are the ```tf-plans```, ```modules``` and ```subscriptions``` folders for?
> They are real life sanitized examples of an Azure infrastructure deployed with Terraform. Execute the folders following their number sequence and fill in the values adapted for your deployment. **Note**: All elements are not provided, so some specifics in the deployments may not work and will need your adjustment. **Good news**: Terraform will complain when it doesn't have everything it needs to execute a Plan.