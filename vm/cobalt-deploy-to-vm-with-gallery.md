# Create and Customize an ARM64 Azure VM from an Azure Compute Gallery

This guide walks you through the process of creating a virtual machine (VM), customizing it, and then using it to create a reusable image in an Azure Compute Gallery. The updated script includes resource existence checks, detailed progress tracking, and improved customization options.

1. Set up the Environment
2. Create a VNET, subnet, and VM
3. Create a new customized VM image in an Azure compute gallery, based on the VM you just created
4. Create a VM from the image gallery

## Prerequisites

- An Azure account with a subscription ID. Sign up for a free account [here](https://azure.microsoft.com/en-us/free/).
- Install the latest Azure CLI. Follow the instructions [here](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli).

## Script Overview

The updated script performs the following operations in four key steps:

1. **Set up the Environment** - Configure variables and check Azure connectivity
2. **Create a Resource Group, VNET, Subnet, and VM** - With existence checks to prevent duplicate resources
3. **Create a customized VM image in an Azure Compute Gallery** - Package your VM into a reusable image
4. **Create a new VM from the gallery image** - Deploy a VM using your custom image

## Step 1: Set up the Environment

The script begins by checking your Azure CLI version and login status, then sets up essential variables:

```bash
# Check Azure CLI version and login status
az version --query '"azure-cli"' -o tsv

# Configure key variables (replace with your values)
export RESOURCE_GROUP_NAME=<your resource group name>
export LOCATION=<your location>
export NETWORK_SUBNET_NAME=<your subnet name>
export NETWORK_NAME=<your vnet name>
export NETWORK_SECURITY_GROUP=<your NSG name>
export SOURCE_VM_NAME=<your source VM name>
export SOURCE_RESOURCE_GROUP_NAME=<your source resource group name>
export TARGET_VM_NAME=<your target VM name>
export VM_IMAGE=<your VM image name>
export VM_IMAGE_VERSION=<your VM image version>
export IMAGE_GALLERY_NAME=<your image gallery name>
```

The script automatically retrieves your current subscription ID:

```bash
# Get current subscription ID
export SUBSCRIPTION_ID=$(az account show --query id -o tsv)
echo "Subscription ID: $SUBSCRIPTION_ID"
```

Then it shows available ARM64 VM images to choose from:

```bash
az vm image list \
    --architecture Arm64 \
    --publisher Canonical \
    --offer ubuntu-minimal \
    --all \
    --query "[?contains(sku, '22_04') || contains(sku, '20_04')].{Offer:offer, Publisher:publisher, SKU:sku, Version:version}" \
    -o table

# Set the ARM64 image to use for the VM
export sourcearmimage=<your ARM image name>
export sourcearmimagename=<your ARM image name>
```

## Step 2: Create a Resource Group, VNET, Subnet, and VM

The script checks for existing resources before creating new ones:

```bash
# Check if resource group exists
echo "Checking if resource group '$RESOURCE_GROUP_NAME' exists..."
RG_EXISTS=$(az group exists --name "$RESOURCE_GROUP_NAME")

if [ "$RG_EXISTS" = "true" ]; then
  echo "Resource group '$RESOURCE_GROUP_NAME' already exists."
else
  echo "Creating resource group '$RESOURCE_GROUP_NAME'..."
  az group create --resource-group "$RESOURCE_GROUP_NAME" --location "$LOCATION"
fi

# Check if vnet exists
echo "Checking if virtual network '$NETWORK_NAME' exists..."
VNET_EXISTS=$(az network vnet list --resource-group "$RESOURCE_GROUP_NAME" --query "[?name=='$NETWORK_NAME'].id" -o tsv)

if [ -n "$VNET_EXISTS" ]; then
  echo "Virtual network '$NETWORK_NAME' already exists."
else
  echo "Creating virtual network '$NETWORK_NAME'..."
  az network vnet create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --location "$LOCATION" \
    --name "$NETWORK_NAME" \
    --address-prefixes "172.0.0.0/16"
fi
   ```

# Check if subnet exists
echo "Checking if subnet '$NETWORK_SUBNET_NAME' exists..."
SUBNET_EXISTS=$(az network vnet subnet list --resource-group "$RESOURCE_GROUP_NAME" --vnet-name "$NETWORK_NAME" --query "[?name=='$NETWORK_SUBNET_NAME'].id" -o tsv)

if [ -n "$SUBNET_EXISTS" ]; then
  echo "Subnet '$NETWORK_SUBNET_NAME' already exists."
else
  echo "Creating subnet '$NETWORK_SUBNET_NAME'..."
  az network vnet subnet create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --vnet-name "$NETWORK_NAME" \
    --address-prefixes "172.0.0.0/24" \
    --name "$NETWORK_SUBNET_NAME"
fi

# Check if VM exists
echo "Checking if source VM '$SOURCE_VM_NAME' exists..."
VM_EXISTS=$(az vm list --resource-group "$RESOURCE_GROUP_NAME" --query "[?name=='$SOURCE_VM_NAME'].id" -o tsv)

if [ -n "$VM_EXISTS" ]; then
  echo "Source VM '$SOURCE_VM_NAME' already exists."
else
  echo "Creating source VM '$SOURCE_VM_NAME' with image $sourcearmimagename..."
  
  echo "This may take a few minutes..."
  az vm create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --location "$LOCATION" \
    --name "$SOURCE_VM_NAME" \
    --image "$sourcearmimagename" \
    --vnet-name "$NETWORK_NAME" \
    --subnet "$NETWORK_SUBNET_NAME" \
    --public-ip-sku Standard \
    --generate-ssh-keys \
    --tags "Environment=Development" "Project=ArmVM" "Purpose=ImageSource"
    echo "Source VM creation complete!"
  
  # Get the public IP address of the VM
  SOURCE_VM_IP=$(az vm show -d -g "$RESOURCE_GROUP_NAME" -n "$SOURCE_VM_NAME" --query publicIps -o tsv)
  echo "Source VM Public IP: $SOURCE_VM_IP"
  
  echo "To install Cassandra on the source VM, connect via SSH:"
  echo "  ssh azureuser@$SOURCE_VM_IP"
  
  echo -e "\nExample commands to install Cassandra on Ubuntu:"
  echo "======================================================================="
  echo "# First, update packages and install dependencies"
  echo "sudo apt-get update && sudo apt-get upgrade -y"
  echo "sudo apt-get install -y apt-transport-https gnupg"
  echo ""
  echo "# Install Java"
  echo "sudo apt-get install -y openjdk-11-jdk"
  echo ""
  echo "# Add Cassandra repository"
  echo "echo \"deb https://debian.cassandra.apache.org 41x main\" | sudo tee -a /etc/apt/sources.list.d/cassandra.sources.list"
  echo "curl https://downloads.apache.org/cassandra/KEYS | sudo apt-key add -"
  echo "sudo apt-get update"
  echo ""
  echo "# Install Cassandra"
  echo "sudo apt-get install -y cassandra"
  echo ""
  echo "# Start Cassandra service"
  echo "sudo systemctl start cassandra"
  echo "sudo systemctl enable cassandra"
  echo ""
  echo "# Check Cassandra status"
  echo "sudo systemctl status cassandra"
  echo "nodetool status"
  echo "cqlsh localhost -e \"describe keyspaces;\""
  echo "======================================================================="
  
  echo -e "\nImportant: Install all necessary software on the source VM before proceeding to Step 3."
  echo "Press Enter when you have finished customizing the source VM..."
  read
fi

## Step 3: Create a customized VM image in an Azure Compute Gallery

After customizing your VM, the script creates an Azure Compute Gallery (if needed):

```bash
# Check if the gallery exists
echo "Checking if image gallery '$IMAGE_GALLERY_NAME' exists..."
GALLERY_EXISTS=$(az sig list --resource-group "$RESOURCE_GROUP_NAME" --query "[?name=='$IMAGE_GALLERY_NAME'].id" -o tsv)

if [ -n "$GALLERY_EXISTS" ]; then
  echo "Image gallery '$IMAGE_GALLERY_NAME' already exists."
else
  echo "Creating image gallery '$IMAGE_GALLERY_NAME'..."
  az sig create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --gallery-name "$IMAGE_GALLERY_NAME" \
    --location "$LOCATION" \
    --description "Gallery for ARM64 VM images"
fi

# Check if the image definition exists
echo "Checking if image definition '$VM_IMAGE' exists..."
IMAGE_DEF_EXISTS=$(az sig image-definition list \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --gallery-name "$IMAGE_GALLERY_NAME" \
  --query "[?name=='$VM_IMAGE'].id" -o tsv)

if [ -n "$IMAGE_DEF_EXISTS" ]; then
  echo "Image definition '$VM_IMAGE' already exists."
else
  echo "Creating image definition '$VM_IMAGE'..."
  az sig image-definition create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --location "$LOCATION" \
    --gallery-name "$IMAGE_GALLERY_NAME" \
    --gallery-image-definition "$VM_IMAGE" \
    --publisher "CustomImages" \
    --offer "CustomVM" \
    --sku "ARM64-Cassandra" \
    --os-type Linux \
    --os-state specialized \
    --hyper-v-generation V2 \
    --architecture Arm64
fi

# Check if the image version exists
echo "Checking if image version '$VM_IMAGE_VERSION' exists..."
IMAGE_VERSION_EXISTS=$(az sig image-version list \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --gallery-name "$IMAGE_GALLERY_NAME" \
  --gallery-image-definition "$VM_IMAGE" \
  --query "[?name=='$VM_IMAGE_VERSION'].id" -o tsv)

if [ -n "$IMAGE_VERSION_EXISTS" ]; then
  echo "Image version '$VM_IMAGE_VERSION' already exists."
else
  # Get the ID of the source VM to use as an image
  echo "Getting ID of source VM '$SOURCE_VM_NAME'..."
  SOURCE_VM_ID=$(az vm get-instance-view -g "$RESOURCE_GROUP_NAME" -n "$SOURCE_VM_NAME" --query id -o tsv)
  
  echo "Creating image version '$VM_IMAGE_VERSION' from source VM..."
  echo "This may take several minutes..."
  
  az sig image-version create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --location "$LOCATION" \
    --gallery-name "$IMAGE_GALLERY_NAME" \
    --gallery-image-definition "$VM_IMAGE" \
    --gallery-image-version "$VM_IMAGE_VERSION" \
    --target-regions "$LOCATION" \
    --replica-count 1 \
    --virtual-machine "$SOURCE_VM_ID"
  
  echo "Image version creation complete!"
fi

## Step 4: Create a VM from the Image Gallery

The script ensures there are no duplicate VMs before creating a new VM from your gallery image:

```bash
# Check if target VM exists
echo "Checking if target VM '$TARGET_VM_NAME' exists..."
TARGET_VM_EXISTS=$(az vm list --resource-group "$RESOURCE_GROUP_NAME" --query "[?name=='$TARGET_VM_NAME'].id" -o tsv)

if [ -n "$TARGET_VM_EXISTS" ]; then
  echo "Target VM '$TARGET_VM_NAME' already exists."
else
  echo "Creating target VM '$TARGET_VM_NAME' from image gallery..."
  echo "This may take a few minutes..."
  
  # Get the image ID from the gallery
  IMAGE_ID="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP_NAME}/providers/Microsoft.Compute/galleries/${IMAGE_GALLERY_NAME}/images/${VM_IMAGE}/versions/${VM_IMAGE_VERSION}"
  
  # Create the VM from the gallery image
  az vm create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --location "$LOCATION" \
    --name "$TARGET_VM_NAME" \
    --image "$IMAGE_ID" \
    --vnet-name "$NETWORK_NAME" \
    --subnet "$NETWORK_SUBNET_NAME" \
    --public-ip-sku Standard \
    --generate-ssh-keys \
    --specialized \
    --tags "Environment=Development" "Project=ArmVM" "Purpose=FromGallery"
  
  echo "Target VM creation complete!"
fi
```

After VM creation, the script configures necessary network access and provides connection information:

```bash
# Open ports for HTTP access
echo "Opening ports 22 (SSH), 80 (HTTP), and 443 (HTTPS) on target VM..."
az vm open-port \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --name "$TARGET_VM_NAME" \
  --port "22,80,443,9042" \
  --priority 100

# Get the public IP address of the target VM
TARGET_VM_IP=$(az vm show -d -g "$RESOURCE_GROUP_NAME" -n "$TARGET_VM_NAME" --query publicIps -o tsv)
echo "Target VM Public IP: $TARGET_VM_IP"

echo "To connect to the target VM via SSH:"
echo "  ssh azureuser@$TARGET_VM_IP"
```

## Verification and Next Steps

Once deployment is complete, verify that Cassandra is running on your new VM:

```bash
# Check Cassandra status remotely
ssh azureuser@$TARGET_VM_IP 'sudo systemctl status cassandra'
ssh azureuser@$TARGET_VM_IP 'nodetool status'
```

### Accessing Your Resources

1. **Azure Portal**: View your VM in the Azure portal with this URL (replace the subscription ID and resource group name):
   ```
   https://portal.azure.com/#@/resource/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP_NAME}/providers/Microsoft.Compute/virtualMachines/${TARGET_VM_NAME}/overview
   ```

2. **SSH Connection**: Connect directly to your VM via SSH:
   ```
   ssh azureuser@<your-vm-ip-address>
   ```

## Benefits of Using Azure Compute Gallery

Azure Compute Gallery (formerly Shared Image Gallery) provides several advantages:

1. **Standardization**: Create and maintain standardized images across your organization
2. **Rapid Deployment**: Quickly deploy multiple identical VMs from your custom image
3. **Version Management**: Track and manage different versions of your VM images
4. **Global Replication**: Replicate images to different Azure regions for faster deployments
5. **Enhanced Security**: Control access to images with Azure RBAC

## Troubleshooting

Here are solutions to common issues you might encounter:

### VM Creation Failures

* **Problem**: VM creation fails with quota or capacity errors
  * **Solution**: Check your subscription limits in the Azure portal and request increases if needed

* **Problem**: Specialized image doesn't start properly
  * **Solution**: Verify that the source VM was properly generalized before creating the image

### Network Connectivity Issues

* **Problem**: Cannot connect to the VM after creation
  * **Solution**: Verify network security group rules and that ports 22, 80, 443, and 9042 are open

### Cassandra Issues

* **Problem**: Cassandra service doesn't start automatically
  * **Solution**: Connect via SSH and run:
    ```bash
    sudo systemctl start cassandra
    sudo systemctl enable cassandra
    ```

* **Problem**: Cannot connect to Cassandra remotely
  * **Solution**: Update `/etc/cassandra/cassandra.yaml` to listen on all interfaces and restart:
    ```bash
    # Set listen_address and rpc_address to your VM's IP
    sudo systemctl restart cassandra
    ```

## Cleaning Up Resources

When you're finished, you can delete all resources to avoid unnecessary charges:

```bash
az group delete --name "$RESOURCE_GROUP_NAME" --yes --no-wait
```

This script provides a complete solution for creating and customizing ARM64 VMs using Azure Compute Gallery, enabling efficient deployment of pre-configured systems.