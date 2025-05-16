#!/bin/bash
# Script to check ARM64 VM quota across multiple Azure regions
# Created: May 2025

echo "=== Checking ARM64 VM Quota Across Regions ==="
echo "This script will check for ARM64 VM quota in key regions"
echo ""

# Define the regions to check
regions=(
    "eastus2"
    "westus2"
    "westeurope"
    "northeurope" 
    "southeastasia"
    "australiaeast"
    "centralus"
    "uksouth"
    "japaneast"
    "eastus"
)

# Get subscription ID and name
subscription_id=$(az account show --query id -o tsv)
subscription_name=$(az account show --query name -o tsv)
echo "Subscription: $subscription_name ($subscription_id)"
echo ""

echo "=== ARM64 VM Family Quota by Region ==="
echo ""

# Check each region for ARM64 VM quotas
for region in "${regions[@]}"; do
    echo "Region: $region"
    echo "------------------------------"
    
    # Check standardDPSv5Family quota (most common ARM64 family)
    az vm list-usage --location "$region" --query "[?contains(name.value, 'standardDPSv5Family')].{Name:name.localizedValue, CurrentUsage:currentValue, Limit:limit}" -o table
    
    # Check standardEPSv5Family quota (memory-optimized ARM64 family)
    az vm list-usage --location "$region" --query "[?contains(name.value, 'standardEPSv5Family')].{Name:name.localizedValue, CurrentUsage:currentValue, Limit:limit}" -o table
    
    # Check standardDPLSv5Family quota (lower memory ARM64 family)
    az vm list-usage --location "$region" --query "[?contains(name.value, 'standardDPLSv5Family')].{Name:name.localizedValue, CurrentUsage:currentValue, Limit:limit}" -o table
    
    echo ""
done

echo "=== Best Options for Deployment ==="
echo "Regions with quota > 8 vCPUs:"

# Find regions with sufficient quota for AKS deployment
for region in "${regions[@]}"; do
    # Get quota values for the three ARM64 VM families
    dps_quota=$(az vm list-usage --location "$region" --query "[?contains(name.value, 'standardDPSv5Family')].limit" -o tsv)
    eps_quota=$(az vm list-usage --location "$region" --query "[?contains(name.value, 'standardEPSv5Family')].limit" -o tsv)
    dpls_quota=$(az vm list-usage --location "$region" --query "[?contains(name.value, 'standardDPLSv5Family')].limit" -o tsv)
    
    # Check if any quota is sufficient (>= 8 vCPUs)
    if [[ -n "$dps_quota" && "$dps_quota" -ge 8 ]]; then
        echo "✅ $region: standardDPSv5Family quota = $dps_quota vCPUs"
    elif [[ -n "$eps_quota" && "$eps_quota" -ge 8 ]]; then
        echo "✅ $region: standardEPSv5Family quota = $eps_quota vCPUs"
    elif [[ -n "$dpls_quota" && "$dpls_quota" -ge 8 ]]; then
        echo "✅ $region: standardDPLSv5Family quota = $dpls_quota vCPUs"
    else
        echo "❌ $region: Insufficient ARM64 VM quota"
    fi
done

echo ""
echo "=== Recommended Next Steps ==="
echo "1. Deploy to a region with sufficient quota (8+ vCPUs)"
echo "2. Use 'export nodeVMSize=Standard_D2ps_v5' for smaller VM size (requires 4+ vCPU quota)"
echo "3. Request quota increase at: https://portal.azure.com/#view/Microsoft_Azure_Capacity/QuotaMenuBlade/~/overview"
