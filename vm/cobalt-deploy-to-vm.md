# Create and Customize an ARM64 Azure VM with the Azure CLI

This guide will walk you through creating and customizing an ARM64 Azure VM using the Azure CLI. The script includes advanced features like resource existence checks and detailed progress information.


## Prerequisites

- An Azure account with a subscription ID. Sign up for a free account [here](https://azure.microsoft.com/en-us/free/).
- Install the latest Azure CLI. Follow the instructions [here](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli).

## Script Overview

The script performs the following operations in four key steps:

1. **Set up the Environment** - Configure variables and check Azure connectivity
2. **Create a Resource Group, VNET, and Subnet** - With existence checks to prevent duplicate resources
3. **Create the VM** - Deploy a new ARM64 VM or verify an existing one
4. **Connect to and Customize the VM** - Instructions for connecting and software installation

## Step 1: Set up the Environment

The script begins by checking your Azure CLI version and login status, then sets up essential variables:

```bash
# Check Azure CLI version and login status
az version --query '"azure-cli"' -o tsv

# Configure key variables (replace with your values)
export RESOURCE_GROUP_NAME=<your resource group name>
export LOCATION=<your location>
export NETWORK_NAME=<your vnet name>
export NETWORK_SUBNET_NAME=<your subnet name>
export VM_NAME=<your VM name>
```

The script then lists available ARM64 VM images, focusing on Ubuntu images from Canonical:

```bash
az vm image list \
    --architecture Arm64 \
    --publisher Canonical \
    --offer ubuntu-minimal \
    --all \
    --query "[?contains(sku, '22_04') || contains(sku, '20_04')].{Offer:offer, Publisher:publisher, SKU:sku, Version:version}" \
    -o table
```

Select and configure your chosen VM image:

```bash
export sourcearmimage=<your ARM image name>
export sourcearmimagename=<your ARM image name>
```

## Step 2: Create a Resource Group, VNET, and Subnet

The script checks for existing resources before creating new ones:

```bash
# Check and create resource group if needed
echo "Checking if resource group '$RESOURCE_GROUP_NAME' exists..."
RG_EXISTS=$(az group exists --name "$RESOURCE_GROUP_NAME")

if [ "$RG_EXISTS" = "true" ]; then
  echo "Resource group '$RESOURCE_GROUP_NAME' already exists."
else
  echo "Creating resource group '$RESOURCE_GROUP_NAME'..."
  az group create --resource-group "$RESOURCE_GROUP_NAME" --location "$LOCATION"
fi
```

The same pattern applies to the VNET and subnet creation, preventing accidental duplicate resources.

## Step 3: Create a VM

The script checks if the VM already exists before attempting to create it:

```bash
echo "Checking if VM '$VM_NAME' exists..."
VM_EXISTS=$(az vm list --resource-group "$RESOURCE_GROUP_NAME" --query "[?name=='$VM_NAME'].id" -o tsv)

if [ -n "$VM_EXISTS" ]; then
  echo "VM '$VM_NAME' already exists."
else
  echo "Creating VM '$VM_NAME' with image $sourcearmimagename..."
  
  az vm create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --location "$LOCATION" \
    --name "$VM_NAME" \
    --image "$sourcearmimagename" \
    --vnet-name "$NETWORK_NAME" \
    --subnet "$NETWORK_SUBNET_NAME" \
    --public-ip-sku Standard \
    --generate-ssh-keys \
    --tags "Environment=Development" "Project=ArmVM"
  
  echo "VM creation complete!"
fi
```

The script also opens necessary network ports:

```bash
az vm open-port \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --name "$VM_NAME" \
  --port "22,80,443" \
  --priority 100
```

## Step 4: Connect to and Customize VM

Once the VM is created, the script displays connection information and provides a sample Cassandra installation script:

```bash
# Get the VM's public IP address
VM_IP=$(az vm show -d -g "$RESOURCE_GROUP_NAME" -n "$VM_NAME" --query publicIps -o tsv)
echo "VM Public IP: $VM_IP"

echo "To connect to the VM via SSH:"
echo "  ssh azureuser@$VM_IP"
```

### Cassandra Installation Example

The script provides a template for installing Cassandra on Ubuntu:

```bash
# First, update packages and install dependencies
sudo apt-get update && sudo apt-get upgrade -y
sudo apt-get install -y apt-transport-https gnupg

# Install Java
sudo apt-get install -y openjdk-11-jdk

# Add Cassandra repository
echo "deb https://debian.cassandra.apache.org 41x main" | sudo tee -a /etc/apt/sources.list.d/cassandra.sources.list
curl https://downloads.apache.org/cassandra/KEYS | sudo apt-key add -
sudo apt-get update

# Install Cassandra
sudo apt-get install -y cassandra

# Start Cassandra service
sudo systemctl start cassandra
sudo systemctl enable cassandra

# Check Cassandra status
sudo systemctl status cassandra
nodetool status
cqlsh localhost -e "describe keyspaces;"
```

## Additional Customization Options

After VM creation, you can customize it further based on your requirements:

- Install additional software packages beyond Cassandra
- Configure system settings and network options
- Set up high availability and backup solutions
- Implement security hardening measures
- Add monitoring and logging solutions

## Performance Considerations for ARM64 VMs

Azure's ARM64 VMs offer several benefits:

- Excellent performance-to-cost ratio for many workloads
- Lower power consumption compared to x86_64 VMs
- Native support for ARM64 applications and containers
- Good scaling for web services, microservices, and databases

## Troubleshooting

If you encounter issues:

1. **Connection problems**: Verify the NSG rules allow SSH on port 22
2. **Resource creation failures**: Check the error messages with `az group deployment operation list`
3. **Performance issues**: Monitor the VM with Azure Monitor to identify bottlenecks

## Next Steps

After creating your VM, consider:

- Setting up monitoring with Azure Monitor
- Implementing automated backups
- Creating a CI/CD pipeline for application deployment
- Setting up load balancing for high availability

For more information on Azure ARM64 VMs, see the [official documentation](https://docs.microsoft.com/en-us/azure/virtual-machines/arm-series).