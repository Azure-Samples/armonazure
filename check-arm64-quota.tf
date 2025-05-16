/*
  filepath: c:\githublocal\armonazure\check-arm64-quota.tf
  Terraform script to check ARM64 VM quota across multiple Azure regions
  Created: May 2025
  Based on the check-arm64-quota.sh bash script
*/

# Configure the Azure Provider
provider "azurerm" {
  features {}
}

# Use local values to define regions to check
locals {
  regions = [
    "eastus2",
    "westus2",
    "westeurope",
    "northeurope",
    "southeastasia",
    "australiaeast",
    "centralus",
    "uksouth",
    "japaneast",
    "eastus"
  ]
}

# Get current subscription details
data "azurerm_subscription" "current" {}

# Use local-exec to query quotas across regions
resource "null_resource" "quota_check" {
  # Run once for each region in the list
  for_each = toset(local.regions)

  provisioner "local-exec" {
    command = <<-EOT
      echo "Region: ${each.key}"
      echo "------------------------------"
      
      # Check standardDPSv5Family quota (most common ARM64 family)
      az vm list-usage --location "${each.key}" --query "[?contains(name.value, 'standardDPSv5Family')].{Name:name.localizedValue, CurrentUsage:currentValue, Limit:limit}" -o table
      
      # Check standardEPSv5Family quota (memory-optimized ARM64 family)
      az vm list-usage --location "${each.key}" --query "[?contains(name.value, 'standardEPSv5Family')].{Name:name.localizedValue, CurrentUsage:currentValue, Limit:limit}" -o table
      
      # Check standardDPLSv5Family quota (lower memory ARM64 family)
      az vm list-usage --location "${each.key}" --query "[?contains(name.value, 'standardDPLSv5Family')].{Name:name.localizedValue, CurrentUsage:currentValue, Limit:limit}" -o table
      
      echo ""
    EOT
  }
}

# Output the summary of suitable regions
resource "null_resource" "quota_summary" {
  depends_on = [null_resource.quota_check]
  
  provisioner "local-exec" {
    command = <<-EOT
      echo "=== ARM64 VM Quota Check Complete ==="
      echo "Subscription: $(az account show --query name -o tsv) ($(az account show --query id -o tsv))"
      echo ""
      echo "=== Best Options for Deployment ==="
      echo "Regions with quota > 8 vCPUs:"
      
      # Find regions with sufficient quota for AKS deployment
      for region in ${join(" ", local.regions)}; do
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
      echo "2. Use VM size Standard_D2ps_v5 for smaller VM size (requires 4+ vCPU quota)"
      echo "3. Request quota increase at the Azure portal Quotas page"
    EOT
  }
}

# Output subscription information
output "subscription_id" {
  value = data.azurerm_subscription.current.subscription_id
  description = "The ID of the current Azure subscription"
}

output "subscription_name" {
  value = data.azurerm_subscription.current.display_name
  description = "The name of the current Azure subscription"
}

output "quota_check_instructions" {
  value = <<-EOT
    To check ARM64 VM quotas, run the following commands:
    
    terraform init
    terraform apply
    
    This will execute the quota checks across all regions and provide a summary
    of the best regions for deployment based on available quota.
  EOT
}
