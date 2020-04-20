$path = "C:\k8s"
$tfv="0.12.24"
$kubv="1.18.0"
# $krewv="0.3.4"

# Ensure Directory exists
If(!(test-path $path))
{
    New-Item -ItemType Directory -Force -Path $path
}

# Load BITS Module
Import-Module BitsTransfer

# Download and install Terraform
$uri="https://releases.hashicorp.com/terraform/${tfv}/terraform_${tfv}_windows_amd64.zip"
$output = "terraform_${tfv}_windows_amd64.zip"
Start-BitsTransfer -Source $uri -Destination $output #-Asynchronous
Expand-Archive $output
Move-Item -Path terraform_${tfv}_windows_amd64\terraform.exe -Destination $path -Force
Remove-Item terraform_${tfv}_windows_amd64
Remove-Item $output


# Download and install kubectl
$uri="https://storage.googleapis.com/kubernetes-release/release/v${kubv}/bin/windows/amd64/kubectl.exe"
$output = "kubectl.exe"
Start-BitsTransfer -Source $uri -Destination $output #-Asynchronous
Move-Item -Path $output -Destination $path -Force


# Download and install kubectxwin
$uri="https://github.com/thomasliddledba/kubectxwin/releases/download/0.1.1/kubectxwin.exe"
$output = "kubectxwin.exe"
Start-BitsTransfer -Source $uri -Destination $output #-Asynchronous
Move-Item -Path $output -Destination $path -Force


# Download and install kubenswin
$uri="https://github.com/thomasliddledba/kubenswin/blob/master/bin/kubenswin.exe"
$output = "kubenswin.exe"
Start-BitsTransfer -Source $uri -Destination $output #-Asynchronous
Move-Item -Path $output -Destination $path -Force

$uri="https://github.com/thomasliddledba/kubenswin/blob/master/bin/kubenswin.exe.config"
$output = "kubenswin.exe.config"
Start-BitsTransfer -Source $uri -Destination $output #-Asynchronous
Move-Item -Path $output -Destination $path -Force


# Set Alias for powershell all users
If(!(test-path $PsHome\profile.ps1)) {
    New-Item -Force -Path $PsHome\profile.ps1
}
Add-Content $PsHome\profile.ps1 "Set-Alias -Name tf -Value $path\terraform.exe" -Force
Add-Content $PsHome\profile.ps1 "Set-Alias -Name k -Value $path\kubectl.exe" -Force
Add-Content $PsHome\profile.ps1 "Set-Alias -Name kctx -Value $path\kubectxwin.exe" -Force
Add-Content $PsHome\profile.ps1 "Set-Alias -Name kns -Value $path\kubenswin.exe" -Force


# # Download and install krew
# $uri="https://github.com/kubernetes-sigs/krew/releases/download/v${krewv}/krew.exe"
# $output = "krew.exe"
# Start-BitsTransfer -Source $uri -Destination $output #-Asynchronous
# Move-Item -Path $output -Destination $path -Force

# $uri="https://github.com/kubernetes-sigs/krew/releases/download/v${krewv}/krew.yaml"
# $output = "krew.yaml"
# Start-BitsTransfer -Source $uri -Destination $output #-Asynchronous
# Move-Item -Path $output -Destination $path -Force