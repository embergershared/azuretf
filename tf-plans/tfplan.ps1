# Description   :
#   This PowerShell script:
#   - Merges Terraform Plans with Values to deploy 1 Infrastructure Instance,
#   - Values are gathered from JSON files in the Instances folder then sourced
#     as TF_VAR_ variables as Environment variables,
#
#   - It requires 2 parameters:
#     - MainTfPath  : is the folder where the Terraform code is (should not have values)
#     - ValuesTfPath: is the folder where the values for the instance to create are
#
#   - It accepts optionals arguments:
#     - "-b": Build   => It fully populates the folder to run Terraform commands in it
#                         To go back to script folder, type "Pop-Location"
#     - "-i": Init    => It fully populates the folder and start Terraform Init
#     - "-p": Plan    => It fully populates the folder and start Terraform Plan
#     - "-d": Destroy => It fully populates the folder and start Terraform Destroy
#        all other arguments or none will run a "Apply"
#
#   Notes:
#   - If using "Build": "Pop-Location" brings you back to the Startedng dir,
#   - Files from the Plan are copied with the prefix "srcd-",
#   - "Press Enter to finish script" will:
#     - Delete the Plan sourced files from the Values folder,
#     - Remove the env:variables TF_VAR_ created in execution context,
#     - Pop execution back to the launching folder.
#
# Folder/File   : /tf-plans/tfplan.ps1
# Created on    : 2020-07-04
# Created by    : Emmanuel
# Last Modified : 2020-09-03
# Last Modif by : Emmanuel

#--------------------------------------------------------------
#   Script parameters inputs
#--------------------------------------------------------------
param ([string] $MainTfPath, [string] $ValuesTfPath)

#--------------------------------------------------------------
#   Processing fixed values
#--------------------------------------------------------------
# Debug preferences:
$DebugPreference = "SilentlyContinue" # "SilentlyContinue" | "Continue" = Debug

# Script constants
$tfexe = "tf"
$ValuesSubscRootPath = "..\subscriptions\"
$PlansRootPath = "..\tf-plans"
$SourcingPrefix = "srcd-"
$TfVariablesFilesPattern = "variables_"

# Selecting if we Execute Terraform or Build the TfPlan in the Values' folder
$Command = "Execute" ; $CleanAtEnd = "true"
if($args.Contains("-b")) { $Command = "Build" ; $CleanAtEnd = "false" }
if($args.Contains("-i")) { $Command = "Init" }
if($args.Contains("-p")) { $Command = "Plan" }
if($args.Contains("-d")) { $Command = "Destroy" }

#--------------------------------------------------------------
#   Script Start
#--------------------------------------------------------------
cls
Write-Debug "Raw arguments are: $args"
Write-Host "Starting ""tfplan.ps1"" with parameters: Command=""$Command"", Main=""$MainTfPath"", Values=""$ValuesTfPath"""

#--------------------------------------------------------------
#   Functions
#--------------------------------------------------------------
function BuildValuesTfPath {
  param([string] $valuesTfPathInput)
  Write-Debug "Started    BuildValuesTfPath($valuesTfPathInput)"
  
  # Test the input
  if (Test-Path -Path $valuesTfPathInput) {
    $global:valueFullPath = (Get-Item $valuesTfPathInput).Fullname
  }
  else {
    # Build the path
    if($valuesTfPathInput.Contains("."))
    {
      $valpath = "$valuesTfPathInput"
    }
    else {
      $valpath = Join-Path -Path $ValuesSubscRootPath -ChildPath $valuesTfPathInput
    }
    $global:valueFullPath = (Get-Item $valpath).Fullname
  }

  Write-Debug "    Built Path: ""$global:valueFullPath"""

  # Test the path exists
  if (!(Test-Path -Path $global:valueFullPath))
  {
    Write-Error "    The Values' Path ""$global:valueFullPath"" doesn't exist."
  }
  else {
    Write-Debug "    Built Path exists."
  }
  Write-Host "Values path is: $global:valueFullPath"
  Write-Debug "Finished BuildValuesTfPath($valuesTfPathInput)"
}
function BuildMainTfPath {
  param([string] $MainTfPathInput)
  Write-Debug "Started  BuildMainTfPath($MainTfPathInput)"
  
  # Build the path
  if($MainTfPathInput.Contains("."))
  {
    $MainTfpath = "$MainTfPathInput"
  }
  else {
    $MainTfpath = Join-Path -Path $PlansRootPath -ChildPath $MainTfPathInput
  }

  $global:planFullPath = (Get-Item $MainTfpath).Fullname

  Write-Debug "    Build Path: ""$global:planFullPath"""

  # Test the path exists
  if (!(Test-Path -Path $global:planFullPath))
  {
    Write-Error "The Main Path ""$global:planFullPath"" doesn't exist."
  }
  else {
    Write-Debug "    Build Path exists."
  }
  Write-Host "Plan   path is: $global:planFullPath"
  Write-Debug "Finished BuildMainTfPath($MainTfPathInput)"
}
function CopyFilesInValuesTfPath {
  Write-Debug "Started  CopyFilesInValuesTfPath()"

  # Clear current value
  $global:sourcedFilesList = ""

  # Build files list:
  #   Terraform plan files
  $global:sourcedFilesList = Get-ChildItem -Path "$global:planFullPath\*" -Include *.tf

  Write-Debug "    Files to be copied in Values Path:"
  $global:sourcedFilesList | ForEach-Object {
    Write-Debug "      $_"
  }

  # Copy the files in Values path
  $global:sourcedFilesList | ForEach-Object {
    Copy-Item $_ -Destination "$global:valueFullPath\$($SourcingPrefix)$($_.Name)" -Force
    Write-Debug "   Copied $_ in $global:valueFullPath"
  }

  Write-Debug "  Copied a total of $($global:sourcedFilesList.Length) files."
  Write-Host  "Copied $($global:sourcedFilesList.Length) ""$($SourcingPrefix)"" files in Values Path."
  Write-Debug "Finished CopyFilesInValuesTfPath()"
}
function SourceValuesInEnvVars {
  Write-Debug "Started  SourceValuesInEnvVars()"

  $global:jsonFiles = @() # Declares it as an array
  $global:nbVarsAdded = 0

  SourceFromTfVarFiles

  # Create TF_VARS for all their elements
  $global:jsonFiles | ForEach-Object {
    Write-Debug "    Processing ""$($_.Name)"""
    if($_) {
      $vars = Get-Content -Raw -Path $($_.FullName) | ConvertFrom-Json
      SourceJson -json $vars
    }
  }

  Write-Host "Processed $($global:jsonFiles.Length) JSON files and $global:nbVarsAdded variables."

  Write-Debug "Finished SourceValuesInEnvVars()"
}
function SourceFromTfVarFiles {
  Write-Debug "Started  SourceFromTfVarFiles()"
  Write-Host "Sourcing Variables values from Terraform Variables files names ($($TfVariablesFilesPattern))."

  Push-Location $global:valueFullPath

  # Listing the Terraform variables files declared for this plan
  $tfvarFiles = ""
  $tfvarFiles = Get-ChildItem -Filter *$($TfVariablesFilesPattern)*.tf -File
  Write-Debug "   Found $($tfvarFiles.Length) variables files for the plan:"
  $tfvarFiles | ForEach-Object {
    Write-Debug "      $_"
  }

  # Extracting required Values files names patterns to find
  Write-Debug "   Extracting JSON files patterns to match"
  $tfvarValuesToSource = @()  # Array of strings
  $tfvarFiles | ForEach-Object {
    $pattern = $($_.Name).Split($TfVariablesFilesPattern)[1].Split(".")[0]
    Write-Debug "      For Variable file: $($_.Name), pattern is: $($pattern)"
    $tfvarValuesToSource += $pattern
  }

  Write-Debug "   Extracted $($tfvarValuesToSource.Length) patterns to match."

  # Searching for the JSON files going up the structure
  $nbValuesToFind = $tfvarValuesToSource.Length
  $tfvarValuesToSource | ForEach-Object {
    $valuesToFind = $_
    Write-Debug "   Finding JSON(s) for: $($valuesToFind)."

    $jsonFile = ""
    $path = Get-Item $global:valueFullPath
    
    Do {
      $test = Get-ChildItem $path -Include *$($valuesToFind)*.json -Recurse -Exclude *.tfvars.json
      if($test){
        $nbValuesToFind -= 1
        $test | ForEach-Object {
          $jsonFile = $_.FullName
          $global:jsonFiles += Get-ChildItem -Path $jsonFile
          Write-Debug "      Found JSON file: $($jsonFile)"
        }
      }
      $path = $path.parent
    } Until ($jsonFile -ne "")
  }

  # Control we have all the values we needed
  Write-Debug "   Remaining patterns to match = $($nbValuesToFind)."

  # Reverse files order to process closest JSON last
  [array]::Reverse($global:jsonFiles)

  Pop-Location

  Write-Debug "Finished SourceFromTfVarFiles()"
}
function SourceJson {
  param([PSObject]$json)

  $json.PSObject.Properties | ForEach-Object {
    Write-Debug "      Sourcing:  ""$($_.Name)"""
    $command = '$env:TF_VAR_' + $_.Name + " = '" + $_.Value + "'"
    try {
      Invoke-Expression $command
      $global:nbVarsAdded += 1
    } catch {
      Write-Debug "        Command Error: $_"
    }
  }
}
function ExecuteTerraform {
  Write-Debug "Started  ExecuteTerraform()"
  Write-Host "Executing Terraform..."

  # Get current location
  Write-Debug "  Current location is: $(Get-location)"

  # Go to Values Full Path
  Push-Location $global:valueFullPath
  Write-Debug "  Moved to: $global:valueFullPath"

  if($Command -ne "Build")
  {
    if($Command -eq "Init")
    {
      TerraformInit
    }

    if($Command -eq "Plan")
    {
      # Is there a .terraform folder?
      if (Test-Path -Path $global:valueFullPath\.terraform)
      {
        Write-Debug "    .terraform folder exists, skipping init."
      }
      else {
        Write-Debug "    .terraform folder doesn't exist, initializing Terraform."
        TerraformInit
      }

      # Execute Terraform Plan command
      TerraformPlan
    }

    if($Command -eq "Execute")
    {
      # Is there a .terraform folder?
      if (Test-Path -Path $global:valueFullPath\.terraform)
      {
        Write-Debug "    .terraform folder exists, skipping init."
      }
      else {
        Write-Debug "    .terraform folder doesn't exist, initializing Terraform."
        TerraformInit
      }

      # Execute Terraform Apply command
      TerraformApply
    }

    if($Command -eq "Destroy")
    {
      TerraformDestroy
    }

    # Wait for cleaning confirmation
    Read-Host "Press Enter to finish script..."

    # Pop back
    Pop-Location
    Write-Debug "  Popped back to: $(Get-Location)"
  }
  
  Write-Host "Finished Terraform."
  Write-Debug "Finished ExecuteTerraform()"
}
function TerraformInit {
  Write-Debug "Started  TerraformInit()"
  try {
    Invoke-Expression "$tfexe init"
  } catch {
    Write-Debug "        Command Error: $_"
  }
  Write-Debug "Finished TerraformInit()"
}
function TerraformPlan {
  Write-Debug "Started  TerraformPlan()"
  try {
    Invoke-Expression "$tfexe plan"
  } catch {
    Write-Debug "        Command Error: $_"
  }
  Write-Debug "Finished TerraformPlan()"
}
function TerraformApply {
  Write-Debug "Started  TerraformApply()"
  try {
    Invoke-Expression "$tfexe apply"
  } catch {
    Write-Debug "        Command Error: $_"
  }
  Write-Debug "Finished TerraformApply()"
}
function TerraformDestroy {
  Write-Debug "Started  TerraformDestroy()"
  try {
    Invoke-Expression "$tfexe destroy"
  } catch {
    Write-Debug "        Command Error: $_"
  }
  Write-Debug "Finished TerraformDestroy()"
}
function ClearValuesInEnvVars {
  Write-Debug "Started  ClearValuesInEnvVars()"

  $global:nbVarsRemoved = 0

  # # List all JSON files in the plan folder
  # $files = Get-ChildItem -Path $global:valueFullPath -Filter *.json

  # Remove TF_VARS for all their elements
  $global:jsonFiles | ForEach-Object {
    Write-Debug "    Processing ""$($_.Name)"""
    if($_) {
      $vars = Get-Content -Raw -Path $($_.FullName) | ConvertFrom-Json
      RemoveJson -json $vars
    }
  }

  # # Clear their TF_VARS
  # $vars = Get-ChildItem Env:TF_VAR_*
  # $vars | ForEach-Object {
  #   Write-Debug "    Removing $($_.Name)"
  #   Remove-Item $_.PSPath
  # }

  Write-Host "Removed $global:nbVarsRemoved ""Env:TF_VAR_*"" Environment variables."

  Write-Debug "Finished ClearValuesInEnvVars()"
}
function RemoveJson {
  param([PSObject]$json)
  $json.PSObject.Properties | ForEach-Object {
    Write-Debug "      Removing:  ""$($_.Name)"""
    $var = Get-Item "Env:TF_VAR_$($_.Name)" -ErrorAction SilentlyContinue
    if($var -ne $null)
    { 
      Remove-Item $var.PSPath
      Write-Debug "      Removed :   Env:$($var.Name) | $($var.Value)"
      $global:nbVarsRemoved += 1
    }
  }
}
function DeleteCopiedFilesInValuesTfPath {
  Write-Debug "Started  DeleteCopiedFilesInValuesTfPath()"

  $global:sourcedFilesRemoved = 0

  # Delete them
  $global:sourcedFilesList | ForEach-Object {
    Remove-Item "$global:valueFullPath\$($SourcingPrefix)$($_.Name)" -Force
    $global:sourcedFilesRemoved += 1
    Write-Debug "   Deleted $($_.Name) from $global:valueFullPath"
  }

  Write-Host  "Deleted $($global:sourcedFilesRemoved) ""$($SourcingPrefix)"" files from Values Path."

  Write-Debug "Finished DeleteCopiedFilesInValuesTfPath()"
}

#--------------------------------------------------------------
#   Main Code
#--------------------------------------------------------------
BuildMainTfPath($MainTfPath)
BuildValuesTfPath($ValuesTfPath)
CopyFilesInValuesTfPath
SourceValuesInEnvVars
ExecuteTerraform             # Some commands are "Execute"& "Init" specific
if($CleanAtEnd -eq "true")
{
  ClearValuesInEnvVars
  DeleteCopiedFilesInValuesTfPath
}

#--------------------------------------------------------------
#   Script End
#--------------------------------------------------------------
Write-Host "Finished ""tfplan.ps1"" script"