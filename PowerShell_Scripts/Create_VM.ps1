Connect-AzAccount

$ResourceGroupName = "RG-Demo"
$location = "West Us 2"
$VnetName = "Vnet-Demo"
$VnetAddressPrefix = "192.168.0.0/16"
$subnetAddressPrefix = "192.168.0.0/24"
$SubnetName = "Subnet-0"
$PublicIpAddress = "pip-demo"
$NetworkSecurity = "nsg-demo"
$NetworkInterface = "nic-demo"
$VMname = "vm-demo" 

# create Resource Group
New-AzResourceGroup -Name $ResourceGroupName -Location $location

# Create Virtual Network
$vnet = New-AzVirtualNetwork -ResourceGroupName $ResourceGroupName -Name $VnetName -Location $location -AddressPrefix $VnetAddressPrefix 

# Create Subnet
$subnet = Add-AzVirtualNetworkSubnetConfig -Name $SubnetName -VirtualNetwork $vnet -AddressPrefix $subnetAddressPrefix
$vnet | Set-AzVirtualNetwork

# Create Public Ip Address
$publicIp = New-AzPublicIpAddress -Name $PublicIpAddress -ResourceGroupName $ResourceGroupName -Location $location -AllocationMethod Static -Sku Standard

# Create Network Security Group (First Create Rules and then Create NSG)
$rdprule = New-AzNetworkSecurityRuleConfig -Name "Allow-RDP" -Access Allow -Priority 100 -Protocol Tcp -Direction Inbound -SourcePortRange "*" -SourceAddressPrefix "*" -DestinationPortRange 3389 -DestinationAddressPrefix "*"
$httprule = New-AzNetworkSecurityRuleConfig -Name "Allow-Http" -Access Allow -Priority 120 -Protocol Tcp -Direction Inbound -SourcePortRange "*" -SourceAddressPrefix "*" -DestinationPortRange 80 -DestinationAddressPrefix "*"

$nsg = New-AzNetworkSecurityGroup -Name $NetworkSecurity -ResourceGroupName $ResourceGroupName -Location $location -SecurityRules $rdprule,$httprule

$httpsrule = Add-AzNetworkSecurityRuleConfig -Name "Allow-Https" -Access Allow -Priority 140 -Protocol Tcp -Direction Inbound -SourcePortRange "*" -SourceAddressPrefix "*" -DestinationPortRange 443 -DestinationAddressPrefix "*" -NetworkSecurityGroup $nsg

$nsg | Set-AzNetworkSecurityGroup
Get-AzNetworkSecurityRuleConfig -NetworkSecurityGroup $nsg

# Create Network Interface Card (NIC)
$subnetid = "subscriptions/4328dfa2-beec-4a59-9d1c-34c94a7d59bc/resourceGroups/RG-Demo/providers/Microsoft.Network/virtualNetworks/Vnet-Demo/Subnets/subnet-0"
$nic = New-AzNetworkInterface -Name $NetworkInterface -ResourceGroupName $ResourceGroupName -Location $location -SubnetId $subnetid -IpConfigurationName "ipconfig" -PublicIpAddressId $publicIp.Id -NetworkSecurityGroupId 

# Create VM Config
$cred = Get-Credential

Get-AzVMSize -Location $location
Get-AzVMImageSku -location $location -PublisherName "MicrosoftWindowsServer" -Offer "WindowsServer"
get-help Set-AzVMSourceImage -Examples
get-help Set-AzVMOSDisk -Examples
get-help Add-AzVMNetworkInterface -Detailed

$vmconfig = New-AzVMConfig -VMName $VMname -VMSize "Standard_DS2_v2"
$vmconfig = Set-AzVMOperatingSystem -VM $vmconfig -Windows -ComputerName "MyVMDemo" -Credential $cred -ProvisionVMAgent -EnableAutoUpdate 
$vmconfig = Set-AzVMSourceImage -VM $vmconfig -PublisherName "MicrosoftWindowsServer" -Offer "WindowsServer" -Skus "2019-Datacenter-smalldisk" -Version "latest"
$vmconfig = Set-AzVMOSDisk -VM $vmconfig -Name "OS_Disk_0" -CreateOption FromImage -DiskSizeInGB 127
$vmconfig = Add-AzVMNetworkInterface -VM $vmconfig -Id $nic.Id

New-AzVM -ResourceGroupName $ResourceGroupName -Location $location -VM $vmconfig

# Attach NSG to the subnet (Nic is connected to that subnet) 
$subnet | Set-AzVirtualNetworkSubnetConfig -NetworkSecurityGroup $nsg -Name $SubnetName -AddressPrefix $subnetAddressPrefix
$vnet | Set-AzVirtualNetwork


