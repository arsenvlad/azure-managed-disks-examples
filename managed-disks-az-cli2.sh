# https://docs.microsoft.com/en-us/cli/azure/install-az-cli2

az --version

#azure-cli (0.1.1b3)
#acr (0.1.1b2)
#acs (0.1.1b3)
#appservice (0.1.1b2)
#cloud (0.1.1b2)
#component (0.1.0rc2)
#configure (0.1.1b3)
#container (0.1.1b2)
#context (0.1.1b2)
#core (0.1.1b3)
#feedback (0.1.1b2)
#network (0.1.1b2)
#nspkg (0.1.2)
#profile (0.1.1b2)
#resource (0.1.1b2)
#role (0.1.1b2)
#storage (0.1.1b2)
#vm (0.1.1b3)
#Python (Windows) 3.5.3 (v3.5.3:1880cb95a742, Jan 16 2017, 16:02:32) [MSC v.1900 64 bit (AMD64)]

# Login
az login

# List subscriptions that your account can access
az account list

# Select specific subscription to work in
az account set --subscription "Subscription Name"

# Create resource group
az group create --name "avtest2" --location "eastus"

# Create virtual network and subnet
az network vnet create --resource-group "avtest2" --location "eastus" --name "avtest-vnet" --address-prefix "10.0.0.0/16" --subnet-name "default" --subnet-prefix "10.0.0.0/24"

# Create public ip
az network public-ip create --resource-group "avtest2" --location "eastus" --name "avtest-publicip"

# List public IP ids
az network public-ip list --query [*].id

# Create network interface
az network nic create --resource-group "avtest2" --location "eastus" --name "avtest-nic" --subnet "/subscriptions/subscription-id/resourceGroups/avtest2/providers/Microsoft.Network/virtualNetworks/avtest-vnet/subnets/default" --public-ip-address "/subscriptions/subscription-id/resourceGroups/avtest2/providers/Microsoft.Network/publicIPAddresses/avtest-publicip"

# Create VM machine with managed OS disk
az vm create --resource-group "avtest2" --location "eastus" --name "avtest-vm" --image "OpenLogic:CentOS:7.3:latest" --size "Standard_DS2_v2" --admin-username "azureuser" --admin-password "P@ssw0rd$123" --authentication-type "password" --nics "/subscriptions/subscription-id/resourceGroups/avtest2/providers/Microsoft.Network/networkInterfaces/avtest-nic" --os-disk-name "avtest-vm-osdisk" -o json

# Create an empty data disk
az disk create --resource-group "avtest2" --location "eastus" --name "avtest-datadisk1" --size-gb 128 --sku "Standard_LRS" -o json

# Attach managed data disk to VM (TODO: this Azure CLI 2.0 command seems to be missing important parameter for setting LUN 0)
az vm disk attach --resource-group "avtest2" --vm-name "avtest-vm" --disk "/subscriptions/subscription-id/resourceGroups/avtest2/providers/Microsoft.Compute/disks/avtest-datadisk1"
az vm disk detach --resource-group "avtest2" --vm-name "avtest-vm" --disk-name "avtest-datadisk1" -o json

# List managed disks in this resource group
az disk list --resource-group "avtest2" -o table

# Create snapshot from disk
az snapshot create --resource-group "avtest2" --name "avtest-osdisk-snapshot" --sku "Standard_LRS" --source "/subscriptions/subscription-id/resourceGroups/avtest2/providers/Microsoft.Compute/disks/avtest-vm-osdisk" -o json

# Create managed disk from snapshot
az disk create --resource-group "avtest2" --name "avtest-vm-copy-osdisk" --sku "Premium_LRS" --source "/subscriptions/subscription-id/resourceGroups/avtest2/providers/Microsoft.Compute/snapshots/avtest-osdisk-snapshot"

# Create VM from the specialized snapshot
az network public-ip create --resource-group "avtest2" --location "eastus" --name "avtest-publicip-copy" -o json
az network nic create --resource-group "avtest2" --location "eastus" --name "avtest-nic-copy" --subnet "/subscriptions/subscription-id/resourceGroups/avtest2/providers/Microsoft.Network/virtualNetworks/avtest-vnet/subnets/default" --public-ip-address "/subscriptions/subscription-id/resourceGroups/avtest2/providers/Microsoft.Network/publicIPAddresses/avtest-publicip-copy" -o json
az vm create --resource-group "avtest2" --location "eastus" --name "avtest-vm-copy" --size "Standard_DS2_v2" --os-type "linux" --attach-os-disk "/subscriptions/subscription-id/resourceGroups/avtest2/providers/Microsoft.Compute/disks/avtest-vm-copy-osdisk" --nics "/subscriptions/subscription-id/resourceGroups/avtest2/providers/Microsoft.Network/networkInterfaces/avtest-nic-copy" -o json

# SSH into the VM to run waagent -deprovision+user within the VM
sudo waagent -deprovision+user -force

# Deallocate the VM and generalize it via ARM
az vm deallocate --resource-group "avtest2" --name "avtest-vm-copy"
az vm generalize --resource-group "avtest2" --name "avtest-vm-copy"

# Create managed image from the generalized VM
az image create --resource-group "avtest2" --location "eastus" --name "avtest-image" --source "/subscriptions/subscription-id/resourceGroups/avtest2/providers/Microsoft.Compute/virtualMachines/avtest-vm-copy" -o json

# Delete previous VM
az vm delete --resource-group "avtest2" --name "avtest-vm-copy"

# Create VM from managed image
az network public-ip create --resource-group "avtest2" --location "eastus" --name "avtest-publicip2" -o json
az network nic create --resource-group "avtest2" --location "eastus" --name "avtest-nic2" --subnet "/subscriptions/subscription-id/resourceGroups/avtest2/providers/Microsoft.Network/virtualNetworks/avtest-vnet/subnets/default" --public-ip-address "/subscriptions/subscription-id/resourceGroups/avtest2/providers/Microsoft.Network/publicIPAddresses/avtest-publicip2" -o json
az vm create --resource-group "avtest2" --location "eastus" --name "avtest-vm2" --size "Standard_DS2_v2" --os-type "linux" --image "/subscriptions/subscription-id/resourceGroups/avtest2/providers/Microsoft.Compute/images/avtest-image" --size "Standard_DS2_v2" --admin-username "azureuser" --admin-password "P@ssw0rd$123" --authentication-type "password" --nics "/subscriptions/subscription-id/resourceGroups/avtest2/providers/Microsoft.Network/networkInterfaces/avtest-nic2" -o json
