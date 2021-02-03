# Azure with Terraform
This repository shares the code created from various contexts to deploy [Azure](https://azure.microsoft.com/) resources and infrastructures using (HashiCorp) [Terraform](https://www.terraform.io/).

This repo is provided as is, with no support or warranty, but this code is used in real scenarios for real customers/workloads, within their contexts.

This is a new picture file.

# Infrastructure as Code
## Challenges
Using IaC (Infrastructure as Code) based on Terraform for more than 2 years, I met 4 challenges I address here:
1. **Start locally, but be ready for Pipelines** deployment later, as easily as possible,
2. **Separate completely the Infrastructure Plans from their Instances' Values** (including defaults, and instances' Terraform backend state persistence),
3. **Set a Variable's value once** for all the instances needing it (never duplicate, never copy/paste values, never store the same value in mutiple places),
4. Acknowledge that **deployments happen in steps & layers** and code accordingly:
    - **A Landing zone (Hub)**:    
    Networking, Policies, Egress & Ingress Firewall, Application Gateway, Key Vault, VPN, Jumpboxes, etc.
    - **Multiple Workloads groups (Spokes)**:    
    Virtual Machines, Storage, AI models, Databases, Functions, Containers instances, etc.
    - **Deployed in sequenced layers**:    
      Deploy in order: Networking > Data > Compute > Application.     
      Delete in reverse order: Application > Compute > Data > etc.

With time, these challenges grew, whichever tools were used in the projects (Jenkins, Azure DevOps, bash and PowerShell scripts, Terraform local, Terraform Cloud, Terraform Enterprise).    
I came to this solution to be a very solid foundation for all cases and evolution scenarios.

## Offered solution
To solve these challenges, I created a PowerShell script, and a structured folders organization.    
The script does these main things:
1. Merges all the Terraform Plan files ```*.tf``` (common, main and variable) into the instance Value folder (with a "srcd-" prefix),
2. Searches for the Variables Terraform declaration files in the Plan folder structure, parsing the ```var_manifest.json```, and adding them into the instance Value folder,
3. Searches for the required Variables' values in ```*.json``` files within the Value folder structure:
    * It extracts a pattern from the Terraform variable declaration file and look for the matching JSON file by its name pattern,
    * For example, a ```variable_tfspn.tf``` Terraform variable file will trigger the search for a ```*tfspn*.json``` values' file,
4. Creates Environment variables on the host for all the Variable/Value pairs,
5. Runs the Terraform command (default is "Apply") in the Value folder,
6. Cleans everything after execution.

## Benefits
This solution addresses the challenges described above in these ways:
* The Plans do not have any data or values (not even default ones) in them:    
They are managed independently from the instances that are deployed from them.    
They mainly consist of:
    * One ```main_*.tf``` file that describes the resources and modules to use in order deploy the infrastructure layer,
    * One ```variables_*.tf``` file that declares the variables needed for the ```main.tf``` file execution.    
    * One ```var_manifest.json``` file that declares the other variables files needed for the ```main.tf``` file execution. So Variables declarations are unique and consistent accross the entire Terraform plans.    
    This variable management approach provides:
      * Preparation for Variables' Groups in Pipelines,
      * Indication of the JSON values files required to execute this plan,
      * Unique variable declaration. If a variable is required in a Plan, add its declaration file in the plan's manifest of this Plan.
* Creating multiple instances of a same Plan is REALLY easy, possible and manageable:    
    * Run the script on the Plan AND with as many different Values folder per instances.    
    * Common and Unique values are managed without redudancy. Want to override a default or common? Just add its variable's value in the instance JSON value file.
* When a Variable Value is set in its JSON file, the script will find it and use it everywhere needed for the plans that use it (by the inclusion of the respective ```variables_*.tf``` in the ```var_manifest.json``` manifest in its Plan folder).
* To transfer these plans in a Pipeline, put the Plans in the repository and choose the best method for your context to provide the variables' values (Variables Groups, Terraform Cloud/Enterprise UI, Terraform API calls, in memory sourcing within the agent with ```TF_VAR_```, generate ```auto.tfvars.tf``` files as artifacts). What matters is that the exact list of variables and values to provide for a plan is declared in the plan's folder.
* The ***Terraform backend*** settings to store the state of the infrastructure instance are set in a ```*_tfstate_*.tf``` file located in the Values folder. This is because each state is unique to its instance. The script merging all the required ```*.tf``` files in the Values folder before execution, creates the consistency of the full instance.    
Additionnally, the Terraform backend settings having to be hard-coded, they cannot reference variables. So, managing them as Values makes a lot of sense. In a Pipeline, these are usually filled by a "token replacement" task. 

# Usage
## General
The general use is simple:
* on a Windows machine with PowerShell and Terraform (>= 0.12),
* Launch PowerShell,
* Go (```cd``` or ```Set-Location```) in the folder where the script file ```tfplan.ps1``` is (in this repo: ```/tf-plans```)

Execute the script with the Plan and Values folders as parameters:    
```.\tfplan.ps1 -PlanTfPath .\1-hub\3-netsharedsvc\ -ValuesTfPath ..\subscriptions\nonprod\1-hub\3-netsharedsvc\```

A typical output will look like this:
```
===================================================================================================
>>> Started tfplan.ps1 script.
Parameters    : Command="AutoApply", Plan=".\1-hub\5-jumpboxes\", Values="..\subscriptions\nonprod\1-hub\5-jumpboxes\"
Plan   path is: \GitHub\azuretf\tf-plans\1-hub\5-jumpboxes\
Values path is: \GitHub\azuretf\subscriptions\nonprod\1-hub\5-jumpboxes\
>>> Sourcing files & values...
Processing Variables manifest found in Plan folder (var_manifest.json).
Copied 5 "srcd-" files in Values Path.
Sourcing Variables values from Terraform Variables files names (var_).
Processed 4 JSON files and 30 variables.
>>> Executing Terraform...
Acquiring state lock. This may take a few moments...
random_pet.win_admin_user[0]: Refreshing state... [id=magical-tadpole]
random_password.win_admin_pwd[0]: Refreshing state... [id=none]
........
Apply complete! Resources: 0 added, 5 changed, 0 destroyed.
>>> Finished Terraform.
>>> Removing files & values...
Removed 30 variables from "Env:".
Deleted 5 "srcd-" files from Values Path.
>>> Finished tfplan.ps1 script.
===================================================================================================
```

## Parameters
| Parameter | Description | Mandatory |
|-----------|-------------|-----------|
| ```-PlanTfPath``` | Used to give the argument of the Terraform Plan path | Yes |
| ```-ValuesTfPath``` | Used to give the argument of the Terraform Values path | Yes |
| ```-b``` | Generates the full build in the Values folder. The script stops and it is possible to execute Terraform commands manually, like ```terraform state list```. Once done, execute ```Pop-Location``` to return to the script path.    **Note**: the environment and copied files are not cleaned. | No |
| ```-i``` | Executes a ```terraform init```    on the Plan + Values. | No |
| ```-d``` | Executes a ```terraform destroy``` on the Plan + Values. | No |
| ```-p``` | Executes a ```terraform plan```    on the Plan + Values. | No |
| ```-a``` | Executes a ```terraform apply --auto-approve```    on the Plan + Values . | No |
| ```-debug``` | Executes the default action ```terraform apply```    on the Plan + Values, with Debug detailed output. | No |
| ```-h``` | Executes the default action ```terraform apply```    on the Plan + Values and halts before cleaning values and files. | No |


Note: Except for the ```-b``` & ```-h``` argument, all other arguments will clean the Values folder and Environment variables created.

## Get started
To get started with the provided plans:
1. Create an Azure Service Principal (Portal, azure CLI, azure PowerShell, etc.) that Terraform will use to create and manage Azure resources,
2. Note the following data: *TenantId*, *SubscriptionId*, *AppId*, *AppSecret*,
3. Give this Service Principal the appropriate permissions (usually Contributor on a subscription),
4. Fill-in *TenantId*, *SubscriptionId*, *AppId* values in the file ```\subscriptions\nonprod\nonprod_tfspn.json```
5. Modify the other values in ```nonprod_tfspn.json``` to your context,
6. Fill-in *AppSecret* value in the file ```\subscriptions\nonprod\nonprod_tfspn_secret.json```
7. Check that the file ```nonprod_tfspn_secret.json``` will not be checked-in your repo,
8. Save the changes,
9. Follow the **steps for the first plan**:    
* The first plan ```\tf-plans\1-hub\1-terraform``` creates a **"Terraform"** resource group, storage account and container to store the Terraform states to follow.    
* To set it up:
    1. Execute the plan a first time:    
    ```.\tfplan.ps1 -PlanTfPath .\1-hub\1-terraform\ -ValuesTfPath ..\subscriptions\nonprod\1-hub\1-terraform\```,
    2. It will create the Resources and store the state locally,
    3. Once done, uncomment the lines 4 to 12 in the file ```\subscriptions\nonprod\1-hub\1-terraform\nonprod_hub_hub-terraform_tfstate``` (remove the starting ```# ```),
    4. Fill in the values for *subscription_id*, *resource_group_name* and *storage_account_name* in the file ```nonprod_hub_hub-terraform_tfstate```,
    5. Save the changes,
    6. Execute the plan a second time, with the ```-i``` argument:    
    ```.\tfplan.ps1 -PlanTfPath .\1-hub\1-terraform\ -ValuesTfPath ..\subscriptions\nonprod\1-hub\1-terraform\ -i```,
    7. Answer ```yes``` to move the state from local to the Azure remote backend,
* You're all set.


## Comments
* By default, the script launches a ```terraform apply```. It saves time from the sequence ```terraform plan``` then ```terraform apply```, and maintain execution consistency.    
To discard changes, just hit enter at prompt.    
To apply changes, type ```yes``` and hit enter.    
* The Plans provided leverage the [Azure Cloud Adoption Framework](https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/), like the [Naming and Tagging](https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/naming-and-tagging) and the [Hub & Spoke architecture](https://docs.microsoft.com/en-us/azure/architecture/reference-architectures/hybrid-networking/hub-spoke). These may not fit your deployments and conventions. Please, adapt to your need.
* The script approach allows these benefits:
  * To develop and debug very easily and quickly (pipelines are slow to run and debug),
  * All pieces stay local and all Terraform CLI commands can be run directly,
  * Commands outputs can be interpreted directly,
* Pipelines can add to these benefits by:
  * Manage Variables' group values,
  * Inject secrets from a Vault,
  * Synchronize some tags and tokens values automatically,

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
* To ensure the processing of ***default values*** without declaring them in the Plan folder, an empty variable Terraform file can be created in the Plan folder. It ensures the default Values JSON file will be processed.    
An example can be found with this file: ```\tf-plans\3-aks\2-cluster\variables_aks-defaults.tf``` it is empty, but it enables the values of this file to be processed: ```\subscriptions\nonprod\3-aks\nonprod_aks_aks-defaults_azure.json``` to create "defaults". In this case, we added this file: ```\subscriptions\nonprod\3-aks\nonprod_aks_aks-defaults_b.json``` which is processed after the ```_azure.json``` and overrides the "defaults" to set some values at the "nonprod / AKS" level.

# Q&A
Why JSON for the values and not Terraform ```(auto.)tfvars.tf```?
> JSON is system independent and can easily be manipulated by PowerShell, bash (or other shells) and CD Pipelines. Using JSON helps to be ready for Pipelines transition and not confuse "Plans" items (in ```*.tf``` files) from values (which are in ```*.json``` files).    

Why set defaults values in JSON and not in the Terraform ```variables_*.tf``` files?
> When declaring a variable in Terraform (```variable name { default = "default value" } ```), a **"default value"** can be set. But this declaration is part of the Plan, it is within the Plan. It defeats the approach of completely separating Plans and Values. It also makes the default values management difficult, especially when the default values are different from an environment type to another (like dev vs. prod).

Why source control the Values' JSON files (except secrets)?    
> A major problem we faced in a project using Terraform Enterprise was that the values are not versioned controlled in Terraform Enterprise. When the value of a variable in a workspace is changed with the UI, there is no way to track it. Source controlling the JSON files allows to track values changes AND use branching for all changes (Plans and/or Values). In the mentioned project, we pushed through the Pipeline the variables values to be used by the workspace before all the Plans execution leveraging curl API calls to set the Terraform Enterprise workspace variables values from our repo (except secrets that were injected by Jenkins).    

Why use the Environment Variables and not a file?
> Using the ```TF_VAR_``` sourcing approach as Environment Variables on the host is more secure than a file with the values. It is mimicking the short lived pipelines agents. If any hang or crash happen, no values' data is persisted. Values are in memory, just for the time they are needed.    

Why use 1 ```main_*.tf``` and multiple ```variables_*.tf``` files?
> The multiple variables files allows to see right away which variables are needed for a plan. It eases the use of Variable Groups in Azure DevOps.    
> The use of 1 main Terraform files (instead of splitted main.tf for the Plan), allows IntelliSense in the IDE to **reference** and debug more easily resources while building the plan.

What are the ```tf-plans```, ```modules```, ```charts``` and ```subscriptions``` folders for?
> They are real life sanitized examples of an Azure infrastructure deployed with Terraform. Execute the folders following their number sequence and fill in the values adapted for your deployment. 
> * ```tf-plans```: contains the Terraform plans with main.tf and variables.tf
> * ```modules```: contains few Terraform modules (reusable grouping of resources)
> * ```charts```: contains few Helm charts I built and use to deploy on Kubernetes clusters
> * ```subscriptions```: contains 2 example subscriptions with empty values to create instances

Why not use ```map(object)``` variable types and iterate to create mulitple instances?
> This approach is used in my current project. It presents 2 main issues:    
> 1. These values cannot be parsed into environment variables. It forces the use of ```(auto.)tfvars.tf``` files,
> 2. If an element is removed of the iteration, Terraform will reorder the keys and Destroy/Recreate the entire array of resources. It ended up deleting Prod resources ... to recreate them identically, just because the key in Terraform dictionary "looked" different (Terraform uses an index, not the keyname).
  It is safer to create x resources or modules instances when x intances are required.

**Note**: All elements are not provided. Some specifics in the deployments may not work and will need your adjustment. For instance, the secrets used in the AKS cluster are pulled through [akv2k8s](https://akv2k8s.io/) from another subscription. **Good news**: Terraform will complain when it doesn't have everything it needs to execute a Plan.
