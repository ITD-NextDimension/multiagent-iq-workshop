#!/usr/bin/env bash
# Remove all resources created by deploy.sh (leaves the resource group intact).
set -euo pipefail

RG="${RG:-rg-multiagent-iq}"
AKS_NAME="${AKS_NAME:-aks-iq-aks-agent-hol}"
PREFIX="${PREFIX:-opciq}"

echo "This deletes: AKS ${AKS_NAME}, ACA apps ${PREFIX}-app / ${PREFIX}-mcp-dataiq,"
echo "session pool ${PREFIX}sandbox, ACA env ${PREFIX}-aca-env, Log Analytics ${PREFIX}-logs,"
echo "and the ACR in ${RG}. The resource group ${RG} is NOT deleted."
read -r -p "Continue? [y/N] " ans
[[ "$ans" == "y" || "$ans" == "Y" ]] || { echo "Aborted."; exit 0; }

az containerapp delete -g "$RG" -n "${PREFIX}-app" --yes 2>/dev/null || true
az containerapp delete -g "$RG" -n "${PREFIX}-mcp-dataiq" --yes 2>/dev/null || true
az containerapp sessionpool delete -g "$RG" -n "${PREFIX}sandbox" --yes 2>/dev/null || true
az containerapp env delete -g "$RG" -n "${PREFIX}-aca-env" --yes 2>/dev/null || true
az aks delete -g "$RG" -n "$AKS_NAME" --yes 2>/dev/null || true
az monitor log-analytics workspace delete -g "$RG" -n "${PREFIX}-logs" --yes 2>/dev/null || true

ACR_NAME="$(az acr list -g "$RG" --query "[?starts_with(name, '${PREFIX}acr')].name | [0]" -o tsv 2>/dev/null || true)"
[[ -n "$ACR_NAME" ]] && az acr delete -g "$RG" -n "$ACR_NAME" --yes 2>/dev/null || true

echo "Teardown complete."
