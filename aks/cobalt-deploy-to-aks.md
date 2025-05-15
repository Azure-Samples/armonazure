# Create a new Azure Kubernetes Service running on Azure Cobalt ARM64 VMs

This guide will walk you through the process of creating an Azure Kubernetes Service (AKS) running Cassandra on Azure Cobalt ARM64 VMs. The updated script includes resource existence checks, detailed progress tracking, and improved customization options.

## Prerequisites

- An Azure account with a subscription ID: [https://azure.microsoft.com/en-us/free/](https://azure.microsoft.com/en-us/free/)
- Install the latest Azure CLI: [https://docs.microsoft.com/en-us/cli/azure/install-azure-cli](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
- Docker installed locally (for ACR image creation): [https://docs.docker.com/get-docker/](https://docs.docker.com/get-docker/)

## Script Overview

The script performs the following operations in four key steps:

1. **Set up the Environment** - Configure variables and check Azure connectivity
2. **Create an Azure Kubernetes Service (AKS)** - Deploy an AKS cluster on ARM64 VMs
3. **Create an Azure Container Registry (ACR)** - Optional step to store container images
4. **Deploy Cassandra to AKS** - Deploy Cassandra either from DockerHub or your ACR

## Step 1: Set up the Environment

The script begins by checking your Azure CLI version and login status, then sets up essential variables:

```bash
# Check Azure CLI version and login status
az version --query '"azure-cli"' -o tsv

# For AKS commands (replace with your values)
export myResourceGroup=<your resource group name>
export mylocation=<your location>
export myAKSCluster=<your AKS cluster name>

# For ACR (Optional)
export myACRName=<your ACR name>
export myACRImage=cassandra
export myACRTag=v1
```

The script then finds available ARM64 VM sizes in your selected region:

```bash
# List available ARM64 VM sizes in the selected region
az vm list-sizes \
  --location "$mylocation" \
  --query "[?contains(name, 'D') && contains(name, 'ps') && contains(name, 'v5')].{Name:name, CPUs:numberOfCores, MemoryGB:memoryInMb}" \
  -o table

# Set the ARM64 VM size for AKS nodes
export nodeVMSize=Standard_D4ps_v5
```

## Step 2: Create Azure Resources

The script checks for existing resources before creating new ones:

```bash
# Check and create resource group if needed
echo "Checking if resource group '$myResourceGroup' exists..."
RG_EXISTS=$(az group exists --name "$myResourceGroup")

if [ "$RG_EXISTS" = "true" ]; then
  echo "Resource group '$myResourceGroup' already exists."
else
  echo "Creating resource group '$myResourceGroup'..."
  az group create --resource-group "$myResourceGroup" --location "$mylocation"
fi

# Check and create AKS cluster if needed
echo "Checking if AKS cluster '$myAKSCluster' exists..."
AKS_EXISTS=$(az aks list --resource-group "$myResourceGroup" --query "[?name=='$myAKSCluster'].id" -o tsv)

if [ -n "$AKS_EXISTS" ]; then
  echo "AKS cluster '$myAKSCluster' already exists."
else
  echo "Creating AKS cluster '$myAKSCluster'..."
  
  az aks create \
    --resource-group "$myResourceGroup" \
    --name "$myAKSCluster" \
    --location "$mylocation" \
    --node-vm-size "$nodeVMSize" \
    --node-count 2 \
    --generate-ssh-keys \
    --network-plugin azure \
    --network-policy azure \
    --tags "Environment=Development" "Project=ArmAKS"
fi
```

After creating the AKS cluster, the script configures kubectl:

```bash
# Install kubectl CLI if not already installed
az aks install-cli

# Get AKS credentials
az aks get-credentials --resource-group "$myResourceGroup" --name "$myAKSCluster" --overwrite-existing

# Verify AKS connection
kubectl get nodes
```

## Step 3: Create an Azure Container Registry (Optional)

If an ACR name is provided, the script creates and configures a container registry:

```bash
# Check and create ACR if needed
echo "Checking if ACR '$myACRName' exists..."
ACR_EXISTS=$(az acr list --resource-group "$myResourceGroup" --query "[?name=='$myACRName'].id" -o tsv)

if [ -n "$ACR_EXISTS" ]; then
  echo "ACR '$myACRName' already exists."
else
  echo "Creating ACR '$myACRName'..."
  az acr create \
    --resource-group "$myResourceGroup" \
    --name "$myACRName" \
    --location "$mylocation" \
    --sku Standard \
    --admin-enabled true
fi

# Log in to the ACR
az acr login --name "$myACRName"

# Attach the ACR to the AKS instance
az aks update -g "$myResourceGroup" -n "$myAKSCluster" --attach-acr "$myACRName"

# Pull and push Cassandra image to ACR
docker pull --platform linux/arm64 cassandra:latest
docker tag cassandra:latest ${myACRName}.azurecr.io/${myACRImage}:${myACRTag}
docker push ${myACRName}.azurecr.io/${myACRImage}:${myACRTag}
```

## Step 4: Deploy Cassandra to AKS

The script offers two deployment options:

### Option 1: Deploy from DockerHub

```bash
# Create deployment file with DockerHub image
cat > cassandra-deployment.yaml << EOF
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: cassandra
  labels:
    app: cassandra
spec:
  serviceName: cassandra
  replicas: 1
  selector:
    matchLabels:
      app: cassandra
  template:
    metadata:
      labels:
        app: cassandra
    spec:
      terminationGracePeriodSeconds: 1800
      containers:
      - name: cassandra
        image: arm64v8/cassandra:latest
        imagePullPolicy: Always
        # ... (configuration details) ...
EOF

kubectl create -f cassandra-deployment.yaml
```

### Option 2: Deploy from ACR

```bash
# Create deployment file with ACR image
cat > cassandra-deployment-from-acr.yaml << EOF
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: cassandra
  labels:
    app: cassandra
spec:
  serviceName: cassandra
  replicas: 1
  selector:
    matchLabels:
      app: cassandra
  template:
    metadata:
      labels:
        app: cassandra
    spec:
      terminationGracePeriodSeconds: 1800
      containers:
      - name: cassandra
        image: ${myACRName}.azurecr.io/${myACRImage}:${myACRTag}
        imagePullPolicy: Always
        # ... (configuration details) ...
EOF

kubectl create -f cassandra-deployment-from-acr.yaml
```

In both cases, the script also creates a Kubernetes service to expose Cassandra:

```bash
# Create service for Cassandra
cat > cassandra-service.yaml << EOF
apiVersion: v1
kind: Service
metadata:
  labels:
    app: cassandra
  name: cassandra
spec:
  clusterIP: None
  ports:
  - port: 9042
    name: cql
  # ... (additional ports) ...
  selector:
    app: cassandra
EOF

kubectl create -f cassandra-service.yaml
```

## Benefits of ARM64 VMs for Kubernetes

Using Azure Cobalt ARM64 VMs for your AKS cluster offers several advantages:

1. **Cost efficiency**: ARM64 VMs typically offer better price-performance ratios
2. **Energy efficiency**: Lower power consumption compared to x86 VMs
3. **Optimized for containerized workloads**: Great for microservices architectures
4. **Native ARM64 container support**: Improved performance for ARM64 containers
5. **Lower TCO**: Reduced long-term operational costs

## Advanced Cassandra Configuration

For production environments, consider these Cassandra optimizations:

- Increase the replica count for high availability
- Configure proper resource requests and limits
- Set up persistent storage with appropriate storage classes
- Implement backup and restore procedures
- Configure JVM settings for optimal performance
- Set up monitoring and alerting

## Troubleshooting

If you encounter issues:

1. **Deployment failures**: Check pod events with `kubectl describe pod <pod-name>`
2. **Connection issues**: Verify network policies and service configurations
3. **Performance problems**: Monitor resources with Kubernetes metrics
4. **Container image issues**: Ensure your ACR is properly configured and attached to AKS

## Next Steps

After deploying Cassandra on AKS, consider:

- Setting up monitoring with Azure Monitor for Containers
- Implementing automated backups
- Creating CI/CD pipelines for application deployment
- Scaling your cluster based on workload requirements
- Setting up disaster recovery procedures

For more information on Azure ARM64 VMs and AKS, see the [official documentation](https://docs.microsoft.com/en-us/azure/aks/).