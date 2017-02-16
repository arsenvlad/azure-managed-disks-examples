https://docs.microsoft.com/en-us/azure/xplat-cli-install

azure --version
# 0.10.9 (node: 4.7.0)

azure login

azure account list
azure account set "Subscription Name"

# Create resource group
azure group create --name "avtest3" --location "eastus"

# As of 2017-02-16, Azure CLI 0.10.9 does not yet provide a way to create VM with managed disks directly. However, you can deploy using an ARM template.
azure group deployment create --resource-group "avtest3" --template-uri https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/101-vm-simple-linux/azuredeploy.json

# Following commands would be relevant if creating the VM via Azure CLI with unmanaged disks
# Create virtual network
# azure network vnet create --resource-group "avtest3" --location "eastus" --name "avtest-vnet" --address-prefixes "10.0.0.0/16"
# Create subnet
# azure network vnet subnet create --resource-group "avtest3" --vnet-name "avtest-vnet" --name "default" --address-prefix "10.0.0.0/24"
# Create public ip
# azure network public-ip create --resource-group "avtest3" --location "eastus" --name "avtest-publicip"
# List public IP ids
# azure network public-ip list --json
# Create network interface
# azure network nic create --resource-group "avtest3" --location "eastus" --name "avtest-nic" --subnet-id "/subscriptions/subscription-id/resourceGroups/avtest2/providers/Microsoft.Network/virtualNetworks/avtest-vnet/subnets/default" --public-ip-id "/subscriptions/subscription-id/resourceGroups/avtest3/providers/Microsoft.Network/publicIPAddresses/avtest-publicip"
# The following command will create VM using unmanaged disks
# azure vm create --resource-group "avtest3" --location "eastus" --name "avtest-vm" --image-urn "OpenLogic:CentOS:7.3:latest" --vm-size "Standard_DS2_v2" --admin-username "azureuser" --admin-password "P@ssw0rd$123" --nic-ids "/subscriptions/subscription-id/resourceGroups/avtest3/providers/Microsoft.Network/networkInterfaces/avtest-nic"

# Create an empty data disk
azure managed-disk create --resource-group "avtest3" --name "avtest-datadisk1" --disk "{\"location\":\"eastus\",\"creationData\":{\"createOption\":\"Empty\"},\"diskSizeGB\":128}"

# List managed disks in this resource group
azure managed-disk list --resource-group "avtest3"

# As of 2017-02-16, Azure CLI 0.10.9 does not yet support imperative commands to attach/detach managed disks to a VM. You can use ARM templates, Azure CLI 2.0, Azure PowerShell, portal.azure.com, or many of the API SDKs

# Create snapshot from disk
azure managed-snapshot create --resource-group "avtest3" --name "avtest-snapshot" --snapshot "{\"location\":\"eastus\",\"creationData\":{\"createOption\":\"Copy\",\"sourceResourceId\":\"/subscriptions/subscription-id/resourceGroups/avtest2/providers/Microsoft.Compute/disks/avtest-datadisk1\"}}"

# Create managed disk from snapshot
azure managed-disk create --resource-group "avtest3" --name "avtest-datadisk1-copy" --disk "{\"location\":\"eastus\",\"creationData\":{\"createOption\":\"Copy\",\"sourceResourceId\":\"/subscriptions/subscription-id/resourceGroups/avtest2/providers/Microsoft.Compute/snapshots/avtest-snapshot\"}}"

# Create managed image from the generalized VM
azure managed-image create --resource-group "avtest3" --name "avtest-image" --parameters "{\"location\":\"eastus\",\"sourceVirtualMachine\":{\"id\":\"/subscriptions/subscription-id/resourceGroups/avtest2/providers/Microsoft.Compute/virtualMachines/avtest-vm2\"}}"

