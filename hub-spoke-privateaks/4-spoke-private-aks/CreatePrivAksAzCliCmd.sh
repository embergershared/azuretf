# Install aks-preview extension to use --node-resource-group
az extension add --name aks-preview

# Create the Private Cluster
az aks create \
    -g "Spoke-Private-AKS-RG" \
    -n "Spoke-Private-AKS-Cluster" \
    --dns-name-prefix "hubspoke-privaks-dns" \
    --kubernetes-version "1.15.10" \
    --node-resource-group "Spoke-Private-AKS-RG-managed" \
    --load-balancer-sku standard \
    --enable-private-cluster \
    --nodepool-name "defaultpool" \
    --max-pods 30 \
    --node-count 1 \
    --node-osdisk-size 80 \
    --node-vm-size "Standard_B2s" \
    --vm-set-type "VirtualMachineScaleSets" \
    --network-plugin "azure" \
    --network-policy "calico" \
    --load-balancer-sku "Standard" \
    --vnet-subnet-id "/subscriptions/abc/resourceGroups/Spoke-Private-AKS-RG/providers/Microsoft.Network/virtualNetworks/Spoke-Private-AKS-NodePools-VNet/subnets/Spoke-Private-AKS-DefaultNodePool-Subnet" \
    --docker-bridge-address 172.17.0.1/16 \
    --dns-service-ip 10.2.0.10 \
    --service-cidr 10.2.0.0/24 \
    --generate-ssh-keys \
    --workspace-resource-id "/subscriptions/abc/resourcegroups/hub-baseservices-rg/providers/microsoft.operationalinsights/workspaces/hub-loganalyticsworkspace" \
    --enable-addons kubeDashboard \
    --enable-addons monitoring

# Can't be done due to Azure AD permissions limitation:
#    --aad-client-app-id "ABC" \
#    --aad-server-app-id "DEF" \
#    --aad-server-app-secret "GHI"

# Finish config as per this article
#   Ref: https://docs.microsoft.com/en-us/azure/aks/private-clusters
#
    
#     Virtual network peering
# As mentioned, VNet peering is one way to access your private cluster. To use VNet peering you need to set up a link between virtual network and the private DNS zone.

# Go to the MC_* resource group in the Azure portal.
# Select the private DNS zone.
# In the left pane, select the Virtual network link.
# Create a new link to add the virtual network of the VM to the private DNS zone. It takes a few minutes for the DNS zone link to become available.

# Go back to the MC_* resource group in the Azure portal.
# In the right pane, select the virtual network. The virtual network name is in the form aks-vnet-*.
# In the left pane, select Peerings.
# Select Add, add the virtual network of the VM, and then create the peering.
# Go to the virtual network where you have the VM, select Peerings, select the AKS virtual network, and then create the peering. If the address ranges on the AKS virtual network and the VM's virtual network clash, peering fails. For more information, see Virtual network peering.

# Dependencies
# The Private Link service is supported on Standard Azure Load Balancer only. Basic Azure Load Balancer isn't supported.
# To use a custom DNS server, add the Azure DNS IP 168.63.129.16 as the upstream DNS server in the custom DNS server.