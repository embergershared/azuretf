$path = "C:\k8s"
$tfv="0.12.24"
$kubv="1.18.0"

# Download and install Terraform
$uri="https://releases.hashicorp.com/terraform/${tfv}/terraform_${tfv}_windows_amd64.zip"
$output = "terraform_${tfv}_windows_amd64.zip"
Import-Module BitsTransfer
Start-BitsTransfer -Source $uri -Destination $output #-Asynchronous
Expand-Archive $output
If(!(test-path $path))
{
    New-Item -ItemType Directory -Force -Path $path
}
Move-Item -Path terraform_${tfv}_windows_amd64\terraform.exe -Destination $path -Force
Remove-Item terraform_${tfv}_windows_amd64
Remove-Item $output

# Download and install kubectl
$uri="https://storage.googleapis.com/kubernetes-release/release/v${kubv}/bin/windows/amd64/kubectl.exe"
$output = "kubectl.exe"
Import-Module BitsTransfer
Start-BitsTransfer -Source $uri -Destination $output #-Asynchronous
Move-Item -Path $output -Destination $path -Force

# Set Alias for powershell all users
If(!(test-path $PsHome\profile.ps1)) {
    New-Item -Force -Path $PsHome\profile.ps1
}
Add-Content $PsHome\profile.ps1 "Set-Alias -Name tf -Value $path\terraform.exe"
Add-Content $PsHome\profile.ps1 "Set-Alias -Name k -Value $path\kubectl.exe"
