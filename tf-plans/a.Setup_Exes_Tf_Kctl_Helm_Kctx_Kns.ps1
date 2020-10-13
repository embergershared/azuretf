# This script downloads and install main binaries for a Kubernetes + Terraform host
cls
Write-Host "Script started"

Write-Host "  Processing variables values"
$path = "C:\k8s"
$tfv="0.13.3"
$kubv="1.18.9"
$hv="3.3.3"
# $krewv="0.3.4"

Write-Host "  Ensure $path directory exists"
# Ensure Directory exists
If(!(test-path $path))
{
  New-Item -ItemType Directory -Force -Path $path
}

# Load BITS Module
Write-Host "  Loading BITS Module"
Import-Module BitsTransfer

# Download and install Terraform
Write-Host "  Processing Terraform v$tfv"

Write-Host "    Downloading Terraform v$tfv"
#   List versions: https://releases.hashicorp.com/terraform/

$uri="https://releases.hashicorp.com/terraform/${tfv}/terraform_${tfv}_windows_amd64.zip"
$output = "terraform_${tfv}_windows_amd64.zip"
Start-BitsTransfer -Source $uri -Destination $output #-Asynchronous
Write-Host "    Unzipping $output"
Expand-Archive $output
Write-Host "    Moving terraform.exe to $path"
Move-Item -Path terraform_${tfv}_windows_amd64\terraform.exe -Destination $path -Force
Write-Host "    Cleaning resources"
Remove-Item terraform_${tfv}_windows_amd64
Remove-Item $output

Write-Host "  Done with Terraform v$tfv"


# Download and install kubectl
Write-Host "  Processing kubectl v$kubv"

Write-Host "    Downloading kubectl v$kubv"
#   List versions: https://github.com/kubernetes/kubernetes/releases

$uri="https://storage.googleapis.com/kubernetes-release/release/v${kubv}/bin/windows/amd64/kubectl.exe"
$output = "kubectl.exe"
Start-BitsTransfer -Source $uri -Destination $output #-Asynchronous
Write-Host "    Moving kubectl.exe to $path"
Move-Item -Path $output -Destination $path -Force

Write-Host "  Done with kubectl v$kubv"


# Download and install Helm
Write-Host "  Processing Helm v$hv"

Write-Host "    Downloading Helm v$hv"
#   List versions: https://github.com/helm/helm/releases
$uri="https://get.helm.sh/helm-v${hv}-windows-amd64.zip"
$output = "helm-v${hv}-windows-amd64.zip"
Start-BitsTransfer -Source $uri -Destination $output #-Asynchronous

Write-Host "    Unzipping $output"
Expand-Archive $output

Write-Host "    Moving Helm.exe to $path"
Move-Item -Path helm-v${hv}-windows-amd64\windows-amd64\helm.exe -Destination $path -Force

Write-Host "    Cleaning resources"
Remove-Item helm-v${hv}-windows-amd64 -Recurse
Remove-Item $output

Write-Host "  Done with Helm v$hv"

# # Commented as the downloaded EXE is corrupted now
# # Use the one available locally.
# # Download and install kubenswin
# Write-Host "  Processing kubenswin"

# $uri="https://github.com/thomasliddledba/kubenswin/blob/master/bin/kubenswin.exe"
# $output = "kubenswin.exe"
# Write-Host "    Downloading kubenswin.exe"
# #Start-BitsTransfer -Source $uri -Destination $output #-Asynchronous
# Invoke-WebRequest -Uri $uri -OutFile $output

# Write-Host "    Moving kubenswin.exe to $path"
# Move-Item -Path $output -Destination $path -Force

# Write-Host "    Downloading kubenswin.exe.config"
# $uri="https://github.com/thomasliddledba/kubenswin/blob/master/bin/kubenswin.exe.config"
# $output = "kubenswin.exe.config"
# #Start-BitsTransfer -Source $uri -Destination $output #-Asynchronous
# Invoke-WebRequest -Uri $uri -OutFile $output

# Write-Host "    Moving kubenswin.exe.config to $path"
# Move-Item -Path $output -Destination $path -Force

# Write-Host "  Done with kubenswin"


# Download and install kubectxwin
Write-Host "  Processing kubectxwin"

Write-Host "    Downloading kubectxwin.exe v0.1.1"
$uri="https://github.com/thomasliddledba/kubectxwin/releases/download/0.1.1/kubectxwin.exe"
$output = "kubectxwin.exe"
#Start-BitsTransfer -Source $uri -Destination $output #-Asynchronous
Invoke-WebRequest -Uri $uri -OutFile $output

Write-Host "    Moving kubectxwin.exe.config to $path"
Move-Item -Path $output -Destination $path -Force

Write-Host "  Done with kubectxwin"


# Adding the folder to the PATH
Write-Host '  Processing $ENV:PATH'
$currPath = (Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name PATH).path
if(!$currPath -contains $path){
    Write-Host "    ""$($path)"" is not present in Env:Path"
    $newPath = "$currPath;$($path)"
    Set-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name PATH -Value $newPath
    Write-Host "    ""$($path)"" was added in Env:Path"
}
else{ Write-Host "    ""$($path)"" is present in Env:Path" }
Write-Host '  Done with $ENV:PATH'


# Set Alias for powershell all users
Write-Host "  Processing PowerShell Aliases"

If(!(test-path $PsHome\profile.ps1)) {
    New-Item -Force -Path $PsHome\profile.ps1
}
$content = Get-Content -Path $PsHome\profile.ps1
$shortcuts = @{ tf = "terraform"; k = "kubectl" ; kctx = "kubectxwin"; kns = "kubenswin"}
$shortcuts.keys | ForEach-Object { 
  Write-Host "    Processing shortcut: $_ for $($shortcuts.$_).exe"
  $aliasToCheckAdd = "Set-Alias -Name $_ -Value $path\$($shortcuts.$_).exe"
  Write-Host "    Checking: ""$aliasToCheckAdd"""
  if(($content -eq $null) -or (!$content.Contains($aliasToCheckAdd))) {
    Write-Host "    Alias is not present, creating it."
    Add-Content $PsHome\profile.ps1 $aliasToCheckAdd -Force
  } else{     Write-Host "    Alias is present." }
}
Write-Host "  Done with PowerShell Aliases"


# # Download and install krew
# $uri="https://github.com/kubernetes-sigs/krew/releases/download/v${krewv}/krew.exe"
# $output = "krew.exe"
# Start-BitsTransfer -Source $uri -Destination $output #-Asynchronous
# Move-Item -Path $output -Destination $path -Force

# $uri="https://github.com/kubernetes-sigs/krew/releases/download/v${krewv}/krew.yaml"
# $output = "krew.yaml"
# Start-BitsTransfer -Source $uri -Destination $output #-Asynchronous
# Move-Item -Path $output -Destination $path -Force

Write-Host "Script finished"