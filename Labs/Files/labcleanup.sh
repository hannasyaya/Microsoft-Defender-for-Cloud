#!/usr/bin/env bash
# Removes the resources created by labdeploy.json (Module 1) so the lab can be
# redeployed cleanly, for example after a failed deployment.
#
# Run it in Azure Cloud Shell (Bash):
#   bash labcleanup.sh <resource-group-name>
#
# It deletes the lab resource group and the AKS node resource group (asclab-aks),
# force-deletes the Log Analytics workspace and purges the soft-deleted Key Vault.
# Without those last two steps, a redeploy fails because both names are reused
# and Azure keeps them reserved for up to 90 days.
#
# It does not change Microsoft Defender for Cloud plans enabled in Exercise 3.

set -euo pipefail

RG="${1:-}"
AKS_RG="asclab-aks"

if [ -z "$RG" ]; then
    echo "Usage: bash labcleanup.sh <resource-group-name>"
    exit 1
fi

echo "Subscription: $(az account show --query '[name, id]' -o tsv | paste -sd ' ')"
read -r -p "Delete resource group '$RG' and '$AKS_RG' with everything in them? (y/N) " answer
[ "$answer" = "y" ] || [ "$answer" = "Y" ] || { echo "Cancelled."; exit 0; }

if [ "$(az group exists -n "$RG")" = "true" ]; then
    # Record the vault names before the group is gone so they can be purged.
    vaults=$(az keyvault list -g "$RG" --query "[].name" -o tsv)

    for ws in $(az monitor log-analytics workspace list -g "$RG" --query "[].name" -o tsv); do
        echo "Force-deleting Log Analytics workspace $ws"
        az monitor log-analytics workspace delete -g "$RG" -n "$ws" --force --yes
    done

    echo "Deleting resource group $RG (this can take 10-15 minutes)"
    az group delete -n "$RG" --yes
else
    echo "Resource group $RG not found, skipping"
    vaults=""
fi

if [ "$(az group exists -n "$AKS_RG")" = "true" ]; then
    echo "Deleting resource group $AKS_RG"
    az group delete -n "$AKS_RG" --yes
fi

# Also catch vaults left soft-deleted by earlier attempts.
vaults="$vaults $(az keyvault list-deleted --query "[?starts_with(name, 'asclab-kv-')].name" -o tsv)"
for kv in $(echo "$vaults" | tr ' ' '\n' | sort -u); do
    if az keyvault show-deleted -n "$kv" >/dev/null 2>&1; then
        echo "Purging soft-deleted Key Vault $kv"
        az keyvault purge -n "$kv"
    fi
done

echo "Cleanup complete."
