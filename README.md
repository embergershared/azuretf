# Azure with Terraform
This repository shares the code created from various contexts to deploy [Azure](https://azure.microsoft.com/) resources and infrastructures using (HashiCorp) [Terraform](https://www.terraform.io/).

It is provided as is, with no support or warranty, but this code is used in real scenarios for real customers/workloads, within their contexts.

# Infrastructure as Code
## Challenges
Using IaC (Infrastructure as Code) based on Terraform for more than 2 years, I met 4 challenges I try to address here and share:
1. **Start locally, but be ready for Pipelines** deployment later, as easily as possible,
2. **Separate completely the Infrastructure Plans from their Instances' Values** (including defaults, and instances' Terraform backend state persistence),
3. **Set a Variable's value once** for all the instances needing it (never duplicate, never copy/paste values, never store the same value in mutiple places),
4. Acknowledge and code accordingly that **deployments happen in steps & layers**:
    - **A Landing zone (Hub)**:    
    Networking, Policies, Egress & Ingress Firewall, Application Gateway, Key Vault, VPN, Jumpboxes, etc.
    - **Multiple Workloads groups (Spokes)**:    
    Virtual Machines, Storage, AI models, Databases, Functions, Containers instances, etc.
    - **Deployed in sequenced layers**:    
      Deploy Networking > Data > Compute > Application.     
      Remove in the reverse order (Application > Compute > etc.).

With time, these challenges grew, whichever tools were used in the projects (Jenkins, Azure DevOps, bash and PowerShell scripts, Terraform local, Terraform Cloud, Terraform Enterprise).    
I came to the above solution to be a very solid foundation in all cases.

## Offered solution
To solve these challenges, I created a PowerShell script, and a structured fodlers organization.    
The script does these main things:
* Merges all the Terraform Plan files ```*.tf``` in the instance Value folder,
* Searches for the Plan required Variables' values in ```*.json``` files, located in the Value folder(s),
* Creates Environment variables on the host for all the Variable/Value pairs required,
* Runs the Terraform command (default is "Apply") in the Value folder,
* Cleans everything after execution.

## Benefits
This solution addresses the challenges described above in these ways:
* The Plans do not have any data or values in them:    
They are managed independently from the instances that are deployed from them.    
They mainly consist of:
    * One ```main_*.tf``` file that describes the resources and modules to use in order deploy the infrastructure layer,
    * Multiple ```variables_*.tf``` files that declare the variables needed for the ```main.tf``` file execution.    
    This variable declaration approach:
      * Prepares for Variables' Groups in Pipelines,
      * Indicates the JSON values files required to execute this plan,
      * Requires (unfortunately) to copy/paste the variables declarations in all the Plans needing to use them (can be improved with a manifest one day).
* Creating multiple instances of a same Plan is REALLY easy, possible and manageable:    
    * Run the script on the same Plan but on as many different Values folder pr instances.    
    * Things that are common will be the same and differences will be different.
* When a Variable Value is set in its JSON file, the script will find it and use it anywhere needed for the plans that use it (by the inclusion of the respective ```variables_.tf``` declaration files in the Plan folder).
* To transfer these plans in a Pipeline, put the Plans in the repository and choose the best method for your context to provide the variables' values (Variables Groups, Terraform Cloud/Enterprise UI, Terraform API calls, in memory sourcing within the agent with ```TF_VAR_```, generate ```auto.tfvars.tf``` files as artifacts). What matters is that the exact list of variables and values to provide for a plan is declared in the plan's folder.
* The Terraform backend settings to store the state of the infrastructure instance are set in a ```state_*,tf``` file located in the Values folder. This is because each state is unique to its instance. The script merging all the required ```*.tf``` files in the Values folder before execution, creates the consistency of the full instance.    
Additionnally, the Terraform backend settings have to be hard-coded, they cannot reference variables. So, managing them as Values makes a lot of sense. In a Pipeline, these are usually filled by a "token replacement" task. 

# Usage
## General
The general use is simple:
* on a Windows machine with PowerShell and Terraform (>= 0.12),
* Launch PowerShell,
* Go (```cd``` or ```Set-Location```) in the folder where the script file ```tfplan.ps1``` is (in this repo: ```/tf-plans```)

Execute the script with the Plan and Values folders as parameters:    
```.\tfplan.ps1 -PlanTfPath .\1-hub\3-sharedsvc\ -ValuesTfPath ..\subscriptions\demo\1-hub\3-sharedsvc\```

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
3. Give this Service Principal the appropriate permissions (usually Contributor on a ubscription),
4. Fill-in *TenantId*, *SubscriptionId*, *AppId* values in the file ``\subscriptions\demo\demo_tfspn.json```
5. Modify the other values in ```demo_tfspn.json``` to your context,
6. Fill-in *AppSecret* value in the file ```\subscriptions\demo\demo_tfspn_secret.json```
7. Check that the file ```demo_tfspn_secret.json``` will not be checked-in your repo,
8. Save the changes,
9. Follow the **steps for the first plan**:    
* The first plan ```\tf-plans\1-hub\1-terraform``` creates a "Terraform" resource group, storage account and container to store the Terraform states to follow.    
* To set it up:
    1. Execute the plan a first time:    
    ```.\tfplan.ps1 -PlanTfPath .\1-hub\1-terraform\ -ValuesTfPath ..\subscriptions\demo\1-hub\1-terraform\```,
    2. It will create the Resources and store the state locally,
    3. Once done, uncomment the lines 4 to 12 in the file ```\subscriptions\demo\1-hub\1-terraform\state_hub-terraform.tf``` (remove the starting ```# ```),
    4. Fill in the values for *subscription_id*, *resource_group_name* and *storage_account_name* in the file ```state_hub-terraform.tf```,
    5. Save the changes,
    6. Execute the plan a second time, with the ```-i``` argument:    
    ```.\tfplan.ps1 -PlanTfPath .\1-hub\1-terraform\ -ValuesTfPath ..\subscriptions\demo\1-hub\1-terraform\ -i```,
    7. Answer ```yes``` to move the state from local to the Azure remote backend,
* You're all set.


## Comments
* By default, the script launches a ```terraform apply```. It saves time from the sequence ```terraform plan``` then ```terraform apply```, and maintain execution consistency.    
To discard changes, just hit enter at prompt.    
To apply changes, type ```yes``` and hit enter.    
* The Plans provided leverage the [Azure Cloud Adoption Framework](https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/), like the [Naming and Tagging](https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/naming-and-tagging) and the [Hub & Spoke architecture](https://docs.microsoft.com/en-us/azure/architecture/reference-architectures/hybrid-networking/hub-spoke). These may not fit your deployments and conventions. Please, adapt to your need.
* The script approach presents these limitations that Pipelines are solving:
  * Have only 1 Variables declaration and reference it accross multiple Plans,
  * Avoid ```locals {  }``` repetitive declaration in all the Values folders,
  * Synchronize some tags and tokens values automatically,    
* But the script approach allows these benefits:
  * To develop and debug very easily and quickly (pipelines are slow to run and debug),
  * All pieces stay local and all Terraform CLI commands can be run directly,
  * Commands outputs can be interpreted directly,

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
* To ensure the processing of default values without declaring them in the Plan folder, an empty variable Terraform file can be created in the Plan folder. It ensures the default Values JSON file will be processed.    
An example can be found with this file: ```\tf-plans\3-aks\2-cluster\variables_aks-defaults.tf``` it is empty, but it enables the values of this file to be processed: ```\subscriptions\demo\3-aks\demo_aks-defaults.json```

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

What are the ```tf-plans```, ```modules``` and ```subscriptions``` folders for?
> They are real life sanitized examples of an Azure infrastructure deployed with Terraform. Execute the folders following their number sequence and fill in the values adapted for your deployment. 

**Note**: All elements are not provided. Some specifics in the deployments may not work and will need your adjustment. For instance, the secrets used in the AKS cluster are pulled through [akv2k8s](https://akv2k8s.io/) from another subscription. **Good news**: Terraform will complain when it doesn't have everything it needs to execute a Plan.