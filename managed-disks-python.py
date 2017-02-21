# Install Azure Python SDK: https://azure-sdk-for-python.readthedocs.io/en/latest/
# pip install azure-mgmt-compute

from azure.common.credentials import ServicePrincipalCredentials
from azure.mgmt.compute import ComputeManagementClient
from azure.mgmt.resource import ResourceManagementClient
from azure.mgmt.network import NetworkManagementClient
from azure.mgmt.compute.models import *
from azure.mgmt.network.models import *

credentials = ServicePrincipalCredentials(
    client_id = "",
    secret = "",
    tenant = ""
)

subscription_id = ""

rg_name = "avtestpy2"
location = "eastus"

resource = ResourceManagementClient(credentials, subscription_id)
compute = ComputeManagementClient(credentials, subscription_id)
network = NetworkManagementClient(credentials, subscription_id)

# Create resource group
print('\nCreate Resource Group')
resource.resource_groups.create_or_update(rg_name, {'location':location})

# Create virtual network
async_op = network.virtual_networks.create_or_update(rg_name, "avtest-vnet",
    {
        'location':location,
        'address_space':{
            'address_prefixes':['10.0.0.0/16']
        },
        'subnets': [
            {
                'name': 'default',
                'address_prefix': '10.0.0.0/24'
            }
        ]
    }
)
async_op.wait()

# Create public IP address
print('\nCreate public IP address')
async_op = network.public_ip_addresses.create_or_update(rg_name, "avtest-publicip", 
    {
        'location':location
    })
async_op.wait()

# Create network interface
print('\nCreate network interface')
subnet = network.subnets.get(rg_name, "avtest-vnet", "default")
public_ip = network.public_ip_addresses.get(rg_name, "avtest-publicip")
async_op = network.network_interfaces.create_or_update(rg_name, "avtest-nic", 
    {
        'location':location,
        'ip_configurations':[{
            'name':'ipConf1',
            'subnet':{
                'id':subnet.id
            },
            'public_ip_address':{
                'id':public_ip.id
            }
        }]
    })
nic = async_op.result()

# Create virtual machine with managed OS Disk
print('\nCreate Linux VM with managed OS disk')
nic = network.network_interfaces.get(rg_name, "avtest-nic")
async_op = compute.virtual_machines.create_or_update(rg_name, "avtest-vm", 
    {
        'location':location,
        'os_profile':{
            'computer_name':'avtest-vm',
            'admin_username':'azureuser',
            'admin_password':'P@ssw0rd$123'
        },
        'hardware_profile':{
            'vm_size':'Standard_DS2_v2'
        },
        'storage_profile':{
            'image_reference':{
                'publisher':'OpenLogic',
                'offer':'CentOS',
                'sku':'7.3',
                'version':'latest'
            },
            'os_disk': {
                'name':'avtest-vm-osdisk',
                'caching':'ReadWrite',
                'create_option':'FromImage',
                'managed_disk':{
                    'storage_account_type':'Premium_LRS'
                }
            }
        },
        'network_profile':{
            'network_interfaces':[{
                'id':nic.id
            }]
        }
    })
vm = async_op.result()

# Create empty data disks
print('\nCreate three empty managed data disks')

async_op1 = compute.disks.create_or_update(rg_name, "avtest-datadisk1", Disk(location, CreationData(create_option = "Empty"), account_type = StorageAccountTypes.standard_lrs, disk_size_gb = 128))
async_op2 = compute.disks.create_or_update(rg_name, "avtest-datadisk2", Disk(location, CreationData(create_option = "Empty"), account_type = StorageAccountTypes.standard_lrs, disk_size_gb = 128))
async_op3 = compute.disks.create_or_update(rg_name, "avtest-datadisk3", Disk(location, CreationData(create_option = "Empty"), account_type = StorageAccountTypes.standard_lrs, disk_size_gb = 128))

async_op1.wait()
async_op2.wait()
async_op3.wait()

# Attach managed data disk to VM 
print('\nVM storage profile of the OS disk:')
vm = compute.virtual_machines.get(rg_name, "avtest-vm")
print(vm.storage_profile.os_disk.managed_disk)

os_disk = compute.disks.get(rg_name, "avtest-vm-osdisk")
data_disk_1 = compute.disks.get(rg_name, "avtest-datadisk1")
data_disk_2 = compute.disks.get(rg_name, "avtest-datadisk2")
data_disk_3 = compute.disks.get(rg_name, "avtest-datadisk3")

print('\nManaged data disk 1:')
print(data_disk_1)

print('\nAttach three managed data disks to VM')
async_op = compute.virtual_machines.create_or_update(rg_name, "avtest-vm",
    {
        'location':location,
        'storage_profile':{
            'data_disks':[
            {
                'lun':0,
                'create_option':'Attach',
                'caching':'ReadOnly',
                'managed_disk':{
                    'id':data_disk_1.id,
                    'storage_account_type':'Premium_LRS'
                }
            },
            {
                'lun':1,
                'create_option':'Attach',
                'caching':'ReadOnly',
                'managed_disk':{
                    'id':data_disk_2.id,
                    'storage_account_type':'Premium_LRS'
                }
            }
            ,
            {
                'lun':2,
                'create_option':'Attach',
                'caching':'ReadOnly',
                'managed_disk':{
                    'id':data_disk_3.id,
                    'storage_account_type':'Standard_LRS'
                }
            }
            ]
        }
    })
async_op.wait()

# Detach managed data disk from VM
vm = compute.virtual_machines.get(rg_name, "avtest-vm")
data_disks = vm.storage_profile.data_disks
print('\nCurrent data disks attached to the VM:')
for disk in data_disks:
    print(disk.managed_disk.id)

print('\nDetach one of the three data disks by name from VM')
data_disks[:] = [disk for disk in data_disks if disk.name != "avtest-datadisk2"]
async_op = compute.virtual_machines.create_or_update(rg_name, "avtest-vm", vm)
async_op.wait()

# # List managed disks in resource group
print('\nList managed disks in resource group')
for disk in compute.disks.list_by_resource_group(rg_name):
    print(disk)

# Create snapshot from disk
print('\nCreate snapshot from managed OS disk')
async_op = compute.snapshots.create_or_update(rg_name, "avtest-vm-osdisk-snapshot", 
    {
        'location':location,
        'creation_data':{
            'create_option':'Copy',
            'source_resource_id':os_disk.id
        }
    })
snapshot = async_op.result()
print(snapshot)

# Create managed disks from Snapshot
print('\nCreate managed disk from snapshot')
snapshot = compute.snapshots.get(rg_name, "avtest-vm-osdisk-snapshot")
async_op = compute.disks.create_or_update(rg_name, "avtest-vm-osdisk-copy", 
    {
        'location':location,
        'creation_data':{
            'create_option':'Copy',
            'source_resource_id':snapshot.id
        }
    })
disk = async_op.result()
print(disk)

print("\nDone")
