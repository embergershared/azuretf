# Variables:
$subId    = ""
$azFwName = ""
$rgName   = ""
$pipName  = ""
$vnetName = ""

# Connect to Azure + Subscription
Connect-AzAccount
$context = Get-AzSubscription -SubscriptionId $subId
Set-AzContext $context

# Stop Azure Firewall
$azfw = Get-AzFirewall -Name $azFwName -ResourceGroupName $rgName
$azfw.Deallocate()
Set-AzFirewall -AzureFirewall $azfw

# Start Azure Firewall
$azfw = Get-AzFirewall -Name $azFwName -ResourceGroupName $rgName
$vnet = Get-AzVirtualNetwork -ResourceGroupName $rgName -Name $vnetName
$publicip1 = Get-AzPublicIpAddress -Name $pipName -ResourceGroupName $rgName
$azfw.Allocate($vnet,@($publicip1))
Set-AzFirewall -AzureFirewall $azfw