Login-AzureRmAccount

Get-AzureRmSubscription
Select-AzureRmSubscription -SubscriptionName ""

# Create resource group
$rgName = "avtest-rg"
$location = "eastus"

New-AzureRmResourceGroup -Name $rgName -Location $location

# Create virtual network, public IP, and network interface
$subnet = New-AzureRmVirtualNetworkSubnetConfig -Name "default" -AddressPrefix "10.0.0.0/24"
$vnet = New-AzureRmVirtualNetwork -Name "avtest-vnet" -ResourceGroupName $rgName -Location $location -AddressPrefix "10.0.0.0/16" -Subnet $subnet
$publicIP = New-AzureRmPublicIpAddress -Name "avtest-publicip" -ResourceGroupName $rgName -Location $location -AllocationMethod Dynamic
$nic = New-AzureRmNetworkInterface -Name "avtest-nic" -ResourceGroupName $rgName -Location $location -SubnetId $vnet.Subnets[0].Id -PublicIpAddressId $publicIP.Id

# Define VM configuration object (no calls to the Azure Resource Management API yet)
$vmConfig = New-AzureRmVMConfig -VMName "avtest-vm" -VMSize "Standard_DS2_v2"
$cred = Get-Credential -Message "Enter the username and password for the administrator account"
$vmConfig = Set-AzureRmVMOperatingSystem -VM $vmConfig -Linux -ComputerName "avtest-vm" -Credential $cred
$vmConfig = Set-AzureRmVMSourceImage -VM $vmConfig -PublisherName "OpenLogic" -Offer "CentOS" -Skus "7.3" -Version "latest"
$vmConfig = Add-AzureRmVMNetworkInterface -VM $vmConfig -Id $nic.Id

# Define the OS managed disk storage account type
$vmConfig = Set-AzureRmVMOSDisk -VM $vmConfig -Name "avtest-vm-osdisk" -StorageAccountType PremiumLRS -CreateOption FromImage -Caching ReadWrite

# Inspect the VM configuration object
$vmConfig

# Actually create the VM by calling Azure Resource Management API and passing the VM configuration defined above
$vm = New-AzureRmVM -ResourceGroupName $rgName -Location $location -VM $vmConfig
$vm

# Create empty data disk
$dataDisk1 = New-AzureRmDiskConfig -Location $location -AccountType StandardLRS -DiskSizeGB 128 -CreateOption Empty
New-AzureRmDisk -ResourceGroupName $rgName -DiskName "avtest-datadisk1" -Disk $dataDisk1

# Attach data disk to VM
$vm = Get-AzureRmVM -ResourceGroupName $rgName -Name "avtest-vm"
$vm = Add-AzureRmVMDataDisk -VM $vm -Name "avtest-datadisk1" -Lun 0 -CreateOption Attach -ManagedDiskId "/subscriptions/subscription-id/resourceGroups/avtest-rg/providers/Microsoft.Compute/disks/avtest-datadisk1"
Update-AzureRmVM -ResourceGroupName $rgName -VM $vm

# Remove data disk from VM
$vm = Get-AzureRmVM -ResourceGroupName $rgName -Name "avtest-vm"
$vm = Remove-AzureRmVMDataDisk -VM $vm -DataDiskNames "avtest-datadisk1"
Update-AzureRmVM -ResourceGroupName $rgName -VM $vm

# Get managed disks in this resource group
Get-AzureRmDisk -ResourceGroupName $rgName

# Create snapshot from the disk
$snapshotConfig = New-AzureRmSnapshotConfig -Location $location -AccountType StandardLRS -CreateOption Copy -SourceResourceId "/subscriptions/subscription-id/resourceGroups/avtest-rg/providers/Microsoft.Compute/disks/avtest-vm_OsDisk_1_97918ea0f8764909b39906ad656d0f47"
$snapshot = New-AzureRmSnapshot -ResourceGroupName $rgName -SnapshotName "avtest-osdisk-snapshot" -Snapshot $snapshotConfig
$snapshot

# Create new copy of managed disk from snapshot
$diskConfig = New-AzureRmDiskConfig -Location $location -AccountType PremiumLRS -OsType Linux -CreateOption Copy -SourceResourceId "/subscriptions/subscription-id/resourceGroups/avtest-rg/providers/Microsoft.Compute/snapshots/avtest-osdisk-snapshot"
New-AzureRmDisk -ResourceGroupName $rgName -DiskName "avtest-osdisk-copy" -Disk $diskConfig

# Create copy VM from the specialized snapshot
$publicIPCopy = New-AzureRmPublicIpAddress -Name "avtest-publicip-copy" -ResourceGroupName $rgName -Location $location -AllocationMethod Dynamic
$nicCopy = New-AzureRmNetworkInterface -Name "avtest-nic-copy" -ResourceGroupName $rgName -Location $location -SubnetId $vnet.Subnets[0].Id -PublicIpAddressId $publicIPCopy.Id

$vmConfigCopy = New-AzureRmVMConfig -VMName "avtest-vm-copy" -VMSize "Standard_DS2_v2"
$vmConfigCopy = Add-AzureRmVMNetworkInterface -VM $vmConfigCopy -Id $nicCopy.Id

# Point to the existing managed disks and use CreateOption=Attach
$vmConfigCopy = Set-AzureRmVMOSDisk -VM $vmConfigCopy -ManagedDiskId "/subscriptions/subscription-id/resourceGroups/avtest-rg/providers/Microsoft.Compute/disks/avtest-osdisk-copy" -CreateOption Attach -Linux -StorageAccountType PremiumLRS -Caching ReadWrite

# Actually create the copy VM by calling Azure Resource Management API and passing the VM configuration defined above
$vmCopy = New-AzureRmVM -ResourceGroupName $rgName -Location $location -VM $vmConfigCopy
$vmCopy
