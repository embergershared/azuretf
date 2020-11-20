# Description   :
#   This PowerShell script:
#   - Merges Terraform Plans with Values to deploy 1 Infrastructure Instance,
#   - Values are gathered from JSON files in the Instances folder then sourced
#     as TF_VAR_ variables as Environment variables,
#
#   - It requires 2 parameters:
#     - PlanTfPath  : is the folder where the Terraform code is (should not have values)
#     - ValuesTfPath: is the folder where the values for the instance to create are
#
#   - It accepts optionals arguments:
#     no args   : Apply       => It fully populates the folder and start Terraform Apply
#     - "-b"    : Build       => It fully populates the folder to run Terraform commands in it
#                               To go back to script folder, type "Pop-Location"
#     - "-i"    : Init        => It fully populates the folder and start Terraform Init
#     - "-p"    : Plan        => It fully populates the folder and start Terraform Plan
#     - "-a"    : Auto Apply  => It fully populates the folder and start Terraform Apply --autoapprove
#     - "-d"    : Destroy     => It fully populates the folder and start Terraform Destroy
#     - "-debug": Verbose     => The script runs in Debug and displays Write-Debug code
#     - "-h"    : Halt        => The script runs and Halt before cleaning and exiting
#        all other arguments or none will run a "Apply"
#
#   Notes:
#   - If using "Build": "Pop-Location" brings you back to the Started dir,
#   - Files from the Plan are copied with the prefix "srcd-",
#   - "Press Enter to finish script" will:
#     - Delete the Plan sourced files from the Values folder,
#     - Remove the env:variables TF_VAR_ created in execution context,
#     - Pop execution back to the launching folder.
#
# Folder/File   : /tf-plans/tfplan.ps1
# Created on    : 2020-07-04
# Created by    : Emmanuel
# Last Modified : 2020-11-20
# Last Modif by : Emmanuel
# Modif scope   : Switched to Variables manifest to remove variables declarations duplicates

#--------------------------------------------------------------
#   Script parameters inputs
#--------------------------------------------------------------
param ([string] $PlanTfPath, [string] $ValuesTfPath)

Write-Host
Write-Host

$extSeparator = "==================================================================================================="
$stepsSeparator = ">>> "
Write-Host $extSeparator
$scriptName = $MyInvocation.MyCommand.Name

#--------------------------------------------------------------
#   Processing fixed values
#--------------------------------------------------------------
# Debug preferences:
if($args.Contains("-debug")) { $DebugPreference = "Continue" }
else { $DebugPreference = "SilentlyContinue" } # "SilentlyContinue" | "Continue" = Debug

# Script constants
$tfexe = "terraform"
$ValuesRootPath = "..\subscriptions\"
$PlansRootPath = "..\tf-plans"
$SourcingPrefix = "srcd-"
$TfVariablesFilesPattern = "var_"
$TfVariablesManifest = "var_manifest.json"
$functionIndent = ""
$functionIdentIncrement = "   "
$debugLevelIndent = "   "

# Selecting if we Execute Terraform or Build the TfPlan in the Values' folder
$Command = "Execute" ; $CleanAtEnd = "true" ; $Halt = "false"
if($args.Contains("-b")) { $Command = "Build" ; $CleanAtEnd = "false" }
if($args.Contains("-i")) { $Command = "Init" }
if($args.Contains("-p")) { $Command = "Plan" }
if($args.Contains("-a")) { $Command = "AutoApply" }
if($args.Contains("-d")) { $Command = "Destroy" }
if($args.Contains("-h")) { $Halt = "true" }

#--------------------------------------------------------------
#   Script Start
#--------------------------------------------------------------
Write-Debug "$($functionIndent)Raw arguments are: $args"
Write-Host "$($stepsSeparator)Started $($scriptName) script."
Write-Host "Parameters    : Command=""$Command"", Plan=""$PlanTfPath"", Values=""$ValuesTfPath"""

#--------------------------------------------------------------
#   Functions
#--------------------------------------------------------------
#   / Generate Full Path
function BuildPlanTfPath {
  param([string] $PlanTfPathInput)
  Write-Debug "$($functionIndent)Started  BuildPlanTfPath($PlanTfPathInput)"
  
  # Build the path
  if($PlanTfPathInput.Contains("."))
  {
    $PlanTfpath = "$PlanTfPathInput"
  }
  else {
    $PlanTfpath = Join-Path -Path $PlansRootPath -ChildPath $PlanTfPathInput
  }

  $global:planFullPath = (Get-Item $PlanTfpath).Fullname

  Write-Debug "$($functionIndent)$($debugLevelIndent)Built Plan   Path: ""$global:planFullPath"""

  # Test the path exists
  if (!(Test-Path -Path $global:planFullPath))
  {
    Write-Error "$($functionIndent)$($debugLevelIndent)Plan Path ""$global:planFullPath"" doesn't exist."
  }
  else {
    Write-Debug "$($functionIndent)$($debugLevelIndent)Plan   Path exists."
  }

  # Calculating the Plan folder depth (to avoid search infinite loop)
  $PlanRootFullPath = (Get-Item $PlansRootPath).Fullname
  $PlanRootFullLevel = $PlanRootFullPath.Split("\").Count
  $planFullLevel = $global:planFullPath.Split("\").Count
  $global:planLevel = $planFullLevel - $PlanRootFullLevel

  Write-Host "Plan   path is: $global:planFullPath"
  Write-Debug "$($functionIndent)$($debugLevelIndent)Plan  depth is: $global:planLevel"

  Write-Debug "$($functionIndent)Finished BuildPlanTfPath($PlanTfPathInput)"
}
function BuildValuesTfPath {
  param([string] $valuesTfPathInput)
  Write-Debug "$($functionIndent)Started    BuildValuesTfPath($valuesTfPathInput)"
  
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
      $valpath = Join-Path -Path $ValuesRootPath -ChildPath $valuesTfPathInput
    }
    $global:valueFullPath = (Get-Item $valpath).Fullname
  }

  Write-Debug "$($functionIndent)$($debugLevelIndent)Built Values Path: ""$global:valueFullPath"""

  # Test the path exists
  if (!(Test-Path -Path $global:valueFullPath))
  {
    Write-Error "$($functionIndent)$($debugLevelIndent)Values Path ""$global:valueFullPath"" doesn't exist."
  }
  else {
    Write-Debug "$($functionIndent)$($debugLevelIndent)Values Path exists."
  }

  # Calculating the Plan folder depth (to avoid search infinite loop)
  $ValuesRootFullPath = (Get-Item $ValuesRootPath).Fullname
  $ValuesRootFullLevel = $ValuesRootFullPath.Split("\").Count
  $valueFullLevel = $global:valueFullPath.Split("\").Count
  $global:valueLevel = $valueFullLevel - $ValuesRootFullLevel +1 # +1 to allow cross subscriptions values

  Write-Host "Values path is: $global:valueFullPath"
  Write-Debug "$($functionIndent)$($debugLevelIndent)Values depth is: $global:valueLevel"

  Write-Debug "$($functionIndent)Finished BuildValuesTfPath($valuesTfPathInput)"
}
#   / Copy Terraform files from Plan to Values' path
function CopyFilesInValuesTfPath {
  Write-Debug "$($functionIndent)Started  CopyFilesInValuesTfPath()"

  # Clear current value
  $global:sourcedFilesList = @() # Declares it as an array

  # Build files list:
  #   Terraform files in the Plan folder
  $global:sourcedFilesList += Get-ChildItem -Path "$global:planFullPath\*" -Include *.tf

  #   Terraform Common file(s)
  $global:sourcedFilesList += Get-ChildItem -Path "$PSScriptRoot\*" -Include *main_common*.tf

  #   Terraform Variables manifest processing
  $functionIndent = $functionIndent + $functionIdentIncrement
  ProcessVariablesManifest
  $functionIndent = $functionIndent.Substring($functionIdentIncrement.length)

  Write-Debug "$($functionIndent)$($debugLevelIndent)Files to be copied in Values Path:"
  $global:sourcedFilesList | ForEach-Object {
    Write-Debug "$($functionIndent)$($debugLevelIndent)$($debugLevelIndent)$_"
  }

  # Copy the files in Values path
  $global:sourcedFilesList | ForEach-Object {
    Copy-Item $_ -Destination "$global:valueFullPath\$($SourcingPrefix)$($_.Name)" -Force
    Write-Debug "$($functionIndent)$($debugLevelIndent)Copied $_ into $global:valueFullPath"
  }

  Write-Debug "$($functionIndent)$($debugLevelIndent)Copied a total of $($global:sourcedFilesList.Length) files."
  Write-Host  "Copied $($global:sourcedFilesList.Length) ""$($SourcingPrefix)"" files in Values Path."
  Write-Debug "$($functionIndent)Finished CopyFilesInValuesTfPath()"
}
function ProcessVariablesManifest {
  Write-Debug "$($functionIndent)Started  ProcessVariablesManifest()"
  
  $tfvarManifestFullPath = "$($global:planFullPath)$($TfVariablesManifest)"
  
  if (Test-Path -Path $tfvarManifestFullPath)
  {
    Write-Host "Processing Variables manifest found in Plan folder ($($TfVariablesManifest))."

    #   Getting the list of Terraform Variables files to find from manifest content
    $tfvarFilesToFind = Get-Content -Path $tfvarManifestFullPath | ConvertFrom-Json
    Write-Debug "$($functionIndent)$($debugLevelIndent)Manifest variable file = $($tfvarManifestFullPath)."
    Write-Debug "$($functionIndent)$($debugLevelIndent)Manifest variable file references $($tfvarFilesToFind.count) files."

    Write-Debug "$($functionIndent)$($debugLevelIndent)Files referenced:"
    $tfvarFilesToFind | ForEach-Object {
      Write-Debug "$($functionIndent)$($debugLevelIndent)$($debugLevelIndent)$($_)"
    }

    # Processing each Variable file to find
    $nbTfvarFilesToFind = $tfvarFilesToFind.count

    $tfvarFilesToFind | ForEach-Object {
      $tfvarFileToFind = $_
      Write-Debug "$($functionIndent)$($debugLevelIndent)Searching Variable file for: $($tfvarFileToFind)"

      $tfvarFileFoundFullName = ""
      $tfvarFileSearchPath = Get-Item $global:planFullPath
      $tfvarFileSearchLevel = 0

      Do {
        # Scanning current folder + subfolders for searched file
        $tfvarFileLevelScanResults = Get-ChildItem $tfvarFileSearchPath -Include *$($tfvarFileToFind)* -Recurse #-Exclude *.tfvars.json
        
        # If matching results found, process:
        if($tfvarFileLevelScanResults) {
          # We found 1/n file(s) so we have 1 less remaining to find
          $nbTfvarFilesToFind -= 1

          Write-Debug "$($functionIndent)$($debugLevelIndent)$($debugLevelIndent)Found $($tfvarFileLevelScanResults.count) Terraform Variable file(s) matching $($tfvarFileToFind) $($tfvarFileSearchLevel) level(s) up."

          # as we can find more than 1 instance, we force to take the 1st in the list
          $tfvarFileLevelScanResults[0] | ForEach-Object {
            # Extract the file Full Name (with Path)
            $tfvarFileFoundFullName = $_.FullName
            # Add the file to the list of files to copy in the Value path
            $global:sourcedFilesList += Get-ChildItem -Path $tfvarFileFoundFullName

            if ($tfvarFileLevelScanResults.count -eq 1) {
              # We processed the 1 file found. It is expected
              Write-Debug "$($functionIndent)$($debugLevelIndent)$($debugLevelIndent)Added Terraform Variable found $($tfvarFileSearchLevel) level(s) up: $($tfvarFileFoundFullName)"
            }
            else{
              # We processed the 1st file of a list of multiples. It is not expected.
              Write-Warning "$($functionIndent)$($debugLevelIndent)$($debugLevelIndent)Added 1st Terraform Variable found $($tfvarFileSearchLevel) level(s) up: $($tfvarFileFoundFullName)"
            }
          }
        }
        
        # As we processed this level, we move up 1 folder and increment level control to be ready for next loop
        $tfvarFileSearchPath = $tfvarFileSearchPath.parent
        $tfvarFileSearchLevel += 1
      }
      # We stop when we either found a file or reached max expected level of search
      Until (($tfvarFileFoundFullName -ne "") -or ($tfvarFileSearchLevel -eq $global:planLevel))

      # We Finished the search. Let's output why
      if ($tfvarFileFoundFullName -ne "") {
        Write-Debug "$($functionIndent)$($debugLevelIndent)Finished search for ""$($tfvarFileToFind)"" with 1 file found and added"
      }
      else {
        if ($tfvarFileSearchLevel -eq $global:planLevel) {
          Write-Debug "$($functionIndent)$($debugLevelIndent)Finished search for ""$($tfvarFileToFind)"" without success in all levels scanned"
        }
        else {
          Write-Error "$($functionIndent)$($debugLevelIndent)Finished search for ""$($tfvarFileToFind)"" with an Error"
        }
      }
    }

    # Control we have all the var files we needed
    Write-Debug "$($functionIndent)$($debugLevelIndent)Remaining variable files to find = $($nbTfvarFilesToFind)."
  }
  else{
    Write-Host "No Variables manifest in Plan folder matching ""$($TfVariablesManifest)""."
  }

  Write-Debug "$($functionIndent)Finished ProcessVariablesManifest()"
}
#   / Source Terraform variables values
function SourceValuesInEnvVars {
  Write-Debug "$($functionIndent)Started  SourceValuesInEnvVars()"

  $global:jsonFiles = @() # Declares it as an array
  $global:nbVarsAdded = 0

  $functionIndent = $functionIndent + $functionIdentIncrement
  SourceFromTfVarFiles
  $functionIndent = $functionIndent.Substring($functionIdentIncrement.length)

  # Create TF_VARS for all their elements
  $global:jsonFiles | ForEach-Object {
    Write-Debug "$($functionIndent)$($debugLevelIndent)Processing ""$($_.Name)"""
    if($_) {
      $vars = Get-Content -Raw -Path $($_.FullName) | ConvertFrom-Json
      $functionIndent = $functionIndent + $functionIdentIncrement
      SourceJson -json $vars
      $functionIndent = $functionIndent.Substring($functionIdentIncrement.length)
    }
  }

  Write-Host "Processed $($global:jsonFiles.Length) JSON files and $global:nbVarsAdded variables."

  Write-Debug "$($functionIndent)Finished SourceValuesInEnvVars()"
}
function SourceFromTfVarFiles {
  Write-Debug "$($functionIndent)Started  SourceFromTfVarFiles()"
  Write-Host "Sourcing Variables values from Terraform Variables files names ($($TfVariablesFilesPattern))."

  Push-Location $global:valueFullPath

  # Listing the Terraform variables files declared for this plan
  $tfvarFilesToSource = @()
  $tfvarFilesToSource = Get-ChildItem -Filter *$($TfVariablesFilesPattern)*.tf -File
  
  Write-Debug "$($functionIndent)$($debugLevelIndent)Found $($tfvarFilesToSource.Count) variables files for the plan:"
  $tfvarFilesToSource | ForEach-Object {
    Write-Debug "$($functionIndent)      $_"
  }

  # Extracting required Values files names from Terraform variables files present
  Write-Debug "$($functionIndent)$($debugLevelIndent)Extracting JSON files patterns to search for"
  $valuesPatternsToSource = @()  # Array of strings
  
  $tfvarFilesToSource | ForEach-Object {
    $pattern = $($_.Name).Split($TfVariablesFilesPattern)[1].Split(".")[0]
    Write-Debug "$($functionIndent)$($debugLevelIndent)$($debugLevelIndent)For Variable file: $($_.Name), pattern is: $($pattern)"
    $valuesPatternsToSource += $pattern
  }

  Write-Debug "$($functionIndent)$($debugLevelIndent)Extracted $($valuesPatternsToSource.Count) patterns to match."

  # Searching for the JSON files going up the structure
  $nbValuesPatternsToSource = $valuesPatternsToSource.Length
  $jsonFilesFound = @()  # Array of strings (emptying it)

  $valuesPatternsToSource | ForEach-Object {
    $valuesPatternToSource = $_
    Write-Debug "$($functionIndent)$($debugLevelIndent)Finding JSON(s) for: $($valuesPatternToSource)"

    $jsonFileFoundFullName = ""
    $jsonFileSearchPath = Get-Item $global:valueFullPath
    $jsonFileSearchLevel = 0

    Do {
      # Scanning current folder + subfolders for searched file
      $jsonFileLevelScanResult = Get-ChildItem $jsonFileSearchPath -Include *$($valuesPatternToSource)*.json -Recurse -Exclude *.tfvars.json

      if($jsonFileLevelScanResult) {
        # We found 1/n file(s) so we have 1 less remaining to find
        $nbValuesPatternsToSource -= 1

        Write-Debug "$($functionIndent)$($debugLevelIndent)$($debugLevelIndent)Found $($jsonFileLevelScanResult.count) JSON file(s) matching $($valuesPatternToSource) $($jsonFileSearchLevel) level(s) up."

        $jsonFileLevelScanResult | ForEach-Object {
          # Extract the file Full Name (with Path)
          $jsonFileFoundFullName = $_.FullName

          $jsonFilesFound += Get-ChildItem -Path $jsonFileFoundFullName
          Write-Debug "$($functionIndent)$($debugLevelIndent)$($debugLevelIndent)Added JSON file: $($jsonFileFoundFullName)"
        }
      }

      # As we processed this level, we move up 1 folder and increment level control to be ready for next loop
      $jsonFileSearchPath = $jsonFileSearchPath.parent
      $jsonFileSearchLevel += 1
    }
    # We stop when we either found a file or reached max expected level of search
    Until (($jsonFileFoundFullName -ne "") -or ($jsonFileSearchLevel -eq $global:valueLevel))
  
    # We Finished the search. Let's output why
    if ($jsonFileFoundFullName -ne "") {
      Write-Debug "$($functionIndent)$($debugLevelIndent)Finished search for ""$($valuesPatternToSource)"" JSON values file(s) with $($jsonFileLevelScanResult.count) file(s) found and added"
    }
    else {
      if ($jsonFileSearchLevel -eq $global:valueLevel) {
        Write-Debug "$($functionIndent)$($debugLevelIndent)Finished search for ""$($valuesPatternToSource)"" JSON values file(s) without success in all levels scanned"
      }
      else {
        Write-Error "$($functionIndent)$($debugLevelIndent)Finished search for ""$($valuesPatternToSource)"" JSON values file(s) with an Error"
      }
    }
  }

  # Control we have all the values we needed
  Write-Debug "$($functionIndent)$($debugLevelIndent)Remaining patterns to match = $($nbValuesPatternsToSource)."

  # Reverse files order to process closest JSON Values last (and eventually override higher levels values)
  Write-Debug "$($functionIndent)$($debugLevelIndent)Ordering JSON files for processing."
  $global:jsonFiles = $jsonFilesFound | Sort-Object Directory

  Pop-Location

  Write-Debug "$($functionIndent)Finished SourceFromTfVarFiles()"
}
function SourceJson {
  param([PSObject]$json)
  Write-Debug "$($functionIndent)Started  SourceJson()"

  $json.PSObject.Properties | ForEach-Object {
    Write-Debug "$($functionIndent)$($debugLevelIndent)Sourcing:  ""$($_.Name)"""
    $command = '$env:TF_VAR_' + $_.Name + " = '" + $_.Value + "'"
    try {
      Invoke-Expression $command
      $global:nbVarsAdded += 1
    } catch {
      Write-Debug "$($functionIndent)$($debugLevelIndent)Command Error: $_"
    }
  }

  Write-Debug "$($functionIndent)Finished SourceJson()"
}
#   / Execute Terraform
function ExecuteTerraform {
  Write-Debug "$($functionIndent)Started  ExecuteTerraform()"

  # Get current location
  Write-Debug "$($functionIndent)$($debugLevelIndent)Current location is: $(Get-location)"

  # Go to Values Full Path
  Push-Location $global:valueFullPath
  Write-Debug "$($functionIndent)$($debugLevelIndent)Moved to: $global:valueFullPath"

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
        Write-Debug "$($functionIndent)$($debugLevelIndent).terraform folder exists, skipping init."
      }
      else {
        Write-Debug "$($functionIndent)$($debugLevelIndent).terraform folder doesn't exist, initializing Terraform."
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
        Write-Debug "$($functionIndent)$($debugLevelIndent).terraform folder exists, skipping init."
      }
      else {
        Write-Debug "$($functionIndent)$($debugLevelIndent).terraform folder doesn't exist, initializing Terraform."
        TerraformInit
      }

      # Execute Terraform Apply command
      TerraformApply
    }

    if($Command -eq "AutoApply")
    {
      # Is there a .terraform folder?
      if (Test-Path -Path $global:valueFullPath\.terraform)
      {
        Write-Debug "$($functionIndent)$($debugLevelIndent).terraform folder exists, skipping init."
      }
      else {
        Write-Debug "$($functionIndent)$($debugLevelIndent).terraform folder doesn't exist, initializing Terraform."
        TerraformInit
      }

      # Execute Terraform Apply -auto-approve command
      TerraformAutoApply
    }

    if($Command -eq "Destroy")
    {
      TerraformDestroy
    }

    if($Halt -eq "true") {
        # Wait for cleaning confirmation
        Read-Host "Press Enter to finish script"
    }

    # Pop back
    Pop-Location
    Write-Debug "$($functionIndent)$($debugLevelIndent)Popped back to: $(Get-Location)"
  }
  
  Write-Debug "$($functionIndent)Finished ExecuteTerraform()"
}
function TerraformInit {
  Write-Debug "$($functionIndent)Started  TerraformInit()"
  try {
    Invoke-Expression "$tfexe init"
  } catch {
    Write-Debug "$($functionIndent)$($debugLevelIndent)Command Error: $_"
  }
  Write-Debug "$($functionIndent)Finished TerraformInit()"
}
function TerraformPlan {
  Write-Debug "$($functionIndent)Started  TerraformPlan()"
  try {
    Invoke-Expression "$tfexe plan"
  } catch {
    Write-Debug "$($functionIndent)$($debugLevelIndent)Command Error: $_"
  }
  Write-Debug "$($functionIndent)Finished TerraformPlan()"
}
function TerraformApply {
  Write-Debug "$($functionIndent)Started  TerraformApply()"
  try {
    Invoke-Expression "$tfexe apply"
  } catch {
    Write-Debug "$($functionIndent)$($debugLevelIndent)Command Error: $_"
  }
  Write-Debug "$($functionIndent)Finished TerraformApply()"
}
function TerraformAutoApply {
  Write-Debug "$($functionIndent)Started  TerraformApply()"
  try {
    Invoke-Expression "$tfexe apply -auto-approve"
  } catch {
    Write-Debug "$($functionIndent)$($debugLevelIndent)Command Error: $_"
  }
  Write-Debug "$($functionIndent)Finished TerraformApply()"
}
function TerraformDestroy {
  Write-Debug "$($functionIndent)Started  TerraformDestroy()"
  try {
    Invoke-Expression "$tfexe destroy"
  } catch {
    Write-Debug "$($functionIndent)$($debugLevelIndent)Command Error: $_"
  }
  Write-Debug "$($functionIndent)Finished TerraformDestroy()"
}
#   / Remove Terraform variables values
function ClearValuesInEnvVars {
  Write-Debug "$($functionIndent)Started  ClearValuesInEnvVars()"

  $global:nbVarsRemoved = 0

  # # List all JSON files in the plan folder
  # $files = Get-ChildItem -Path $global:valueFullPath -Filter *.json

  # Remove TF_VARS for all their elements
  $global:jsonFiles | ForEach-Object {
    Write-Debug "$($functionIndent)$($debugLevelIndent)Processing ""$($_.Name)"""
    if($_) {
      $vars = Get-Content -Raw -Path $($_.FullName) | ConvertFrom-Json
      RemoveJson -json $vars
    }
  }

  Write-Host "Removed $global:nbVarsRemoved ""Env:TF_VAR_*"" Environment variables."

  Write-Debug "$($functionIndent)Finished ClearValuesInEnvVars()"
}
function RemoveJson {
  param([PSObject]$json)
  $json.PSObject.Properties | ForEach-Object {
    Write-Debug "$($functionIndent)$($debugLevelIndent)Removing:  ""$($_.Name)"""
    $var = Get-Item "Env:TF_VAR_$($_.Name)" -ErrorAction SilentlyContinue
    if($var -ne $null)
    { 
      Remove-Item $var.PSPath
      Write-Debug "$($functionIndent)$($debugLevelIndent)Removed :   Env:$($var.Name) | $($var.Value)"
      $global:nbVarsRemoved += 1
    }
  }
}
function ClearAllEnvTfVars {
  Write-Debug "$($functionIndent)Started  ClearAllEnvTfVars()"

  $global:nbVarsRemoved = 0

  $vars = Get-ChildItem "env:TF_VAR_*"
  $vars | ForEach-Object {
    Write-Debug "$($functionIndent)$($debugLevelIndent)Removing: Env:$($_.Name)"
    $var = Get-Item "Env:$($_.Name)" -ErrorAction SilentlyContinue
    if($var -ne $null)
    { 
      Remove-Item $var.PSPath
      Write-Debug "$($functionIndent)$($debugLevelIndent)$($debugLevelIndent)Removed : Env:$($var.Name) | $($var.Value)"
      $global:nbVarsRemoved += 1
    }
  }
  Write-Host  "Removed $($global:nbVarsRemoved) variables from ""Env:""."

  Write-Debug "$($functionIndent)Finished ClearAllEnvTfVars()"
}
#   / Delete copied files from Values' path
function DeleteCopiedFilesInValuesTfPath {
  Write-Debug "$($functionIndent)Started  DeleteCopiedFilesInValuesTfPath()"

  $global:sourcedFilesRemoved = 0

  # Delete them
  $global:sourcedFilesList | ForEach-Object {
    Remove-Item "$global:valueFullPath\$($SourcingPrefix)$($_.Name)" -Force
    $global:sourcedFilesRemoved += 1
    Write-Debug "$($functionIndent)$($debugLevelIndent)Deleted $($_.Name) from $global:valueFullPath"
  }

  Write-Host  "Deleted $($global:sourcedFilesRemoved) ""$($SourcingPrefix)"" files from Values Path."

  Write-Debug "$($functionIndent)Finished DeleteCopiedFilesInValuesTfPath()"
}

#--------------------------------------------------------------
#   Script Main
#--------------------------------------------------------------
BuildPlanTfPath($PlanTfPath)
BuildValuesTfPath($ValuesTfPath)

Write-Host "$($stepsSeparator)Sourcing files & values..."
CopyFilesInValuesTfPath
SourceValuesInEnvVars

Write-Host "$($stepsSeparator)Executing Terraform..."
ExecuteTerraform             # Some commands are "Execute"& "Init" specific
Write-Host "$($stepsSeparator)Finished Terraform."

if($CleanAtEnd -eq "true")
{
  Write-Host "$($stepsSeparator)Removing files & values..."
  #ClearValuesInEnvVars
  ClearAllEnvTfVars
  DeleteCopiedFilesInValuesTfPath
}

#--------------------------------------------------------------
#   Script End
#--------------------------------------------------------------
Write-Host "$($stepsSeparator)Finished $($scriptName) script."
Write-Host $extSeparator

Write-Host
Write-Host