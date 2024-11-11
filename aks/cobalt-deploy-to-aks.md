# Create a new Azure Kubernetes Service running on Azure Cobalt ARM64 VMs


This guide will walk you through the process of creating an Azure Kubernetes Service (AKS) running Cassandra on an zure Cobalt ARM64 VM in 4 steps:

1. Set up the Environment
2. Create an Azure Kubernetes Service AKS running on ARM64
3. Create an Azure Container Registry (ACR) (Optional)
4. Deploy Cassandra to the Azure Kubernetes Service (AKS)

## Watch the recording:
Coming soon!  

## Prerequisites

- An Azure account with a subscription ID: [https://azure.microsoft.com/en-us/free/](https://azure.microsoft.com/en-us/free/)
- Install the Azure CLI: [https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest)

## Step 1: Set up the Environment

```bash
export myResourceGroup=<your resource group name>
export mylocation=<your location>
export myAKSCluster=<your AKS cluster name>
```

For ACR (Optional):

```bash
export myACRName=<your ACR name>
export myACRImage=${myACRName}:v1
```

Ensure that ARM64 images are available in the Azure region you are deploying to:

```bash
az vm image list \
    --all \
    --location $mylocation \
    --architecture Arm64 \
    --publisher Canonical \
    -o table

```

Set the ARM64 image to use for the VM:

```bash
export sourcearmimage=<your ARM image name>
export sourcearmimagename=<your ARM image name>
```



Create a resource group:

```bash
az group create --resource-group $myResourceGroup --location $mylocation
```

## Step 2: Create an Azure Kubernetes Service AKS running on ARM64

Choose a Cobalt-based Dpsv6, Dpdsv6, Dplsv6, Dpldsv6, Epsv6, or Epdsv6 VM series for --node-vm-size:

```bash
az aks create \
    --resource-group $myResourceGroup \
    --name $myAKSCluster \
    --location $mylocation \
    --node-vm-size $sourcearmimagename \
    --node-count 1 \
    --generate-ssh-keys
```

Example: Deploy AKS on the Cobalt-based Standard_D2pds_v6 VM series in eastus:

```bash
az aks create \
    --resource-group $myResourceGroup \
    --name $myAKSCluster \
    --location eastus \
    --node-vm-size Standard_D2pds_v6 \
    --node-count 5 \
    --generate-ssh-keys
```

Install kubectl in the Azure CLI, connected to AKS:

```bash
az aks install-cli
```

Get the credentials of the new AKS cluster:

```bash
az aks get-credentials --resource-group $myResourceGroup --name $myAKSCluster --overwrite-existing
```

## Step 3: Create an Azure Container Registry (ACR) (Optional)

```bash
az acr create \
    --resource-group $myResourceGroup \
    --name $myACRName \
    --location $mylocation \
    --sku Standard \
    --admin-enabled true
```

Log in to the ACR:

```bash
az acr login --name $myACRName
```

Attach the ACR to the AKS instance:

```bash
az aks update -g $myResourceGroup -n $myAKSCluster --attach-acr $myACRName
```

Add the current Cassandra arm64 Docker Hub image to your ACR:

```bash
docker pull --platform linux/arm64 cassandra:latest
docker tag cassandra:latest ${myACRName}.azurecr.io/$myACRImage
docker push ${myACRName}.azurecr.io/$myACRImage
```

## Step 4: Deploy Cassandra to the Azure Kubernetes Service (AKS)

### Option 1 - Deploying from Docker Hub

Current image: [https://hub.docker.com/r/arm64v8/cassandra/](https://hub.docker.com/r/arm64v8/cassandra/)

```bash
kubectl create -f cassandra-deployment.yaml
kubectl create -f cassandra-service.yaml
kubectl get pods -l app=cassandra
kubectl logs <pod name for cassandra>
```

### Option 2 - Deploying from ACR

Edit `cassandra-deployment-from-acr.yaml` to specify the ACR repository image to deploy:

```yaml
containers:
       - name: cassandra
         image: myACRName.azurecr.io/myACRImage:myACRImageVersion
```

```bash
kubectl create -f cassandra-deployment-from-acr.yaml
kubectl create -f cassandra-service.yaml
kubectl get pods -l app=cassandra
kubectl logs <pod name for cassandra>
```

After completing these steps, you will have successfully created an Azure Kubernetes Service (AKS) running Cassandra on Azure Cobalt ARM64 VMs.