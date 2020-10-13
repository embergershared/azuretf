# https://docs.microsoft.com/en-us/azure/virtual-machines/windows/cli-ps-findimage

# List Publishers
$locName = "canadacentral"
Get-AzVMImagePublisher -Location $locName | Select PublisherName

# List offers
$pubName = "MicrosoftWindowsDesktop"    # MicrosoftWindowsDesktop | MicrosoftWindowsServer
Get-AzVMImageOffer -Location $locName -PublisherName $pubName | Select Offer

# List SKUs
$offerName = "Windows-10"               # Windows-10 | WindowsServer
Get-AzVMImageSku -Location $locName -PublisherName $pubName -Offer $offerName | Select Skus

# Find Image version
$skuName = "20h1-pro"                   # 20h1-pro | 2019-Datacenter
Get-AzVMImage -Location $locName -PublisherName $pubName -Offer $offerName -Sku $skuName | Select Version

# Win 10 versions:  19041.450.2008080726,  19041.508.2009070256
# Win 2019:         latest