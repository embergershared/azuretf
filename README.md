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
To solve these challenges, I created a PowerShell script, and a structured organisation of all the pieces.    
The script does these main things:
* Merges all the Terraform files ```*.tf``` in a folder,
* Searches for the values in ```*.json``` files,
* Creates the Environment variables for the Variable/Value pairs for this execution,
* Runs the Terraform command (default is "Apply") in the folder,
* Cleans everything after execution.

## Benefits
This solution solves the challenges this way:
* The Plans do not have any data or values in them:    
They are managed independently from the instances that are deployed from them.    
They mainly consist of:
    * The ```main.tf``` file that describes the resources and modules to deploy the infrastructure,
    * 1/n ```variables_*.tf``` files that declares the variables needed for the ```main.tf``` file execution.    
    Separating in multiple files the variables declaration:
      * Prepares for Variables' Groups in Pipelines,
      * Indicates the JSON values files required to execute this plan,
      * Unfortunately, requires some copy/paste (that could be improved with a manifest).
* Creating multiple instances of a same Plan is REALLY easy, possible and managed:    
    * Run the script pointing on the same Plan and a different Values folder.    
    * Things that are common will be the same and differences will be different.
* When a Variable Value is set in its JSON file, the script will find it and use it anytime needed for the plans that use it (by their inclusion of the respective ```variables_.tf```).
* To transfer these plans in a Pipeline, put the Plans in the repository and choose the best method for the variables values (Variables Groups, Terraform Cloud/Enterprise UI, Terraform API calls, in memory sourcing within the agent with ```TF_VAR_```, generate ```auto.tfvars.tf``` files as artifacts). What matters is that the exact list of variables and values to provide for a plan is declared in the plan's folder.
* The Terraform backend settings to store the state of the infrastructure instance are set in a ```state_*,tf``` file located in the Values folder. This is because each state is unique for each instance. The script merging all the required ```*.tf``` files in the Values folder before execution, creates the consistency of the full plan.    
Additionnally, the Terraform backend settings have to be hard-coded, they cannot reference variables. So, managing them as Values makes a lot of sense.

# Usage
## General
The general use is simple:
* on a Windows Machine with PowerShell,
* Go in the folder that has the script file ```tfplan.ps1``` (in the repo: ```/tf-plans```)

Execute the script with the Plan and the Values folders as parameters:    
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
    >>> Terraform messaged and processing <<<
Press Enter to finish script...
Finished Terraform.
Removed 7 "Env:TF_VAR_*" Environment variables.
Deleted 3 "srcd-" files from Values Path.
Finished "tfplan.ps1" script
```

## Parameters


## Examples


## Conventions
* The JSON file with the values for a set of variables must have the same name pattern:
    * the values for ```variables_tfspn.tf``` must be in a JSON file named by this pattern: ```*tfspn*.json```,
    * the values can be split in multiples files, like ```tfspn.json``` and ```tfspn_secret.json``` to prevent secrets commit in the repo,
* The script looks for file matching the variables going up in the folder structure:
    * It starts in the Value folder given as argument,
      * if no JSON files match the pattern,
      * It goes up one folder, then search again,
      * Once found at 1 level, it stops here,
    * once all the variables required values are found, the values are processing in reverse: It ensures that the value set the closest to the Values folder will be the one applied.
    * It is usefull to override some defaults values specifically for in 1 instance.


# Q&A
Why JSON for the values and not Terraform ```(auto.)tfvars.tf```?
> JSON is system independent and can easily be manipulated by PowerShell, bash (or other shells) and CD Pipelines. Using JSON helps to be ready for Pipelines transition.    

Why set defaults values in JSON and not in the Terraform ```variables*.tf``` files?
> When declaring a variable in Terraform (```variable name { default = "default value" } ```), a default value can be set. But this declaration is part of the Plan, it is witihn the Plan. It defeats the approach of completely separating Plans from Values. It also makes the default values management difficult, especially when the (default) values are different, for example from an environment type to another.

Why source control the Values' JSON files (except secrets)?    
> A major problem we faced in a project using Terraform Enterprise was that the values are not versioned controlled in Terraform Enterprise. When a the value of a variable in a workspace is changed in the UI, there is no way to track it. Source controlling the JSON files allows to track values changes AND use branching for all changes (Plans and/or Values). In the mentioned project, we pushed through the Pipeline the variables values to be used by the workspace before all the Plans execution, through curl API calls.    

Why use the Environment Variables and not a file?
> Using ```TF_VAR_``` sourcing approach in Environment Variables of the host is more secured than a file with the values. It is mimicking the pipelines agents short-term lifecycle. If any bug or hang happens, no values data is persisted on a storage. Values are in memory, just for the time they are needed.