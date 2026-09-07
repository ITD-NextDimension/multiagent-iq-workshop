#!/usr/bin/env bash
# =============================================================================
# End-to-end deployment for OPC Multi-Agent IQ.
#   ACR -> build 3 images -> Bicep (LA, ACA env, MCP+dataIQ app, web app,
#   session pool sandbox, AKS, federated identity) -> agents workload on AKS
#   -> wire web app.
#
# Auth:
#   - AKS agents authenticate to Azure OpenAI (Foundry) with Entra ID via AKS
#     Workload Identity (DefaultAzureCredential). No AZURE_OPENAI_API_KEY needed.
#   - The two container apps pull images from ACR using the registry admin
#     credentials (avoids the AcrPull role-propagation race).
#
# Prereqs: az CLI (logged in), kubectl, an agents/.env with AZURE_OPENAI_ENDPOINT
#          / AZURE_OPENAI_MODEL / AZURE_OPENAI_API_VERSION set (no API key).
# =============================================================================
set -euo pipefail

RG="${RG:-rg-multiagent-iq}"
LOCATION="${LOCATION:-swedencentral}"
AKS_NAME="${AKS_NAME:-aks-iq-aks-agent-hol}"
PREFIX="${PREFIX:-opciq}"
IMAGE_TAG="${IMAGE_TAG:-$(date -u +%Y%m%d%H%M%S)}"

CLOUD_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(cd "$CLOUD_DIR/.." && pwd)"

# Stable, globally-unique ACR name derived from the subscription id.
SUB_ID="$(az account show --query id -o tsv)"
ACR_NAME="${ACR_NAME:-${PREFIX}acr$(echo "$SUB_ID" | tr -d '-' | cut -c1-12)}"
export ACR_NAME IMAGE_TAG

echo "==> Resource group : $RG ($LOCATION)"
echo "==> ACR            : $ACR_NAME"
echo "==> AKS            : $AKS_NAME"

# Every `az deployment group create` below needs the resource group to exist
# already; nothing in this repo used to create it, so a first run in a fresh
# subscription failed on step 1 with "ResourceGroupNotFound".
if ! az group show --name "$RG" --only-show-errors >/dev/null 2>&1; then
  echo "==> [0/6] Creating resource group $RG"
  az group create --name "$RG" --location "$LOCATION" --only-show-errors >/dev/null
fi

# RG, AKS and ACR names are constants here (ACR is derived from the subscription
# id), so a whole classroom deploying into one subscription would target the same
# cluster and registry and overwrite each other. deploy.sh is documented as
# re-runnable, so this warns rather than blocks — but it names the override.
if az aks show -g "$RG" -n "$AKS_NAME" --only-show-errors >/dev/null 2>&1; then
  echo "!!  AKS '$AKS_NAME' already exists in '$RG'."
  echo "!!  Re-running is fine if this deployment is yours; it will be updated in place."
  echo "!!  If someone else in this subscription created it, YOUR RUN WILL OVERWRITE THEIRS."
  echo "!!  Use your own names:  RG=rg-<you> PREFIX=<you> AKS_NAME=aks-<you> bash scripts/deploy.sh"
  echo "!!  Or run Lab 05-1, which shares one instructor-owned deployment by design."
  echo
fi

# 1) Create the ACR first so we can build/push images into it.
echo "==> [1/6] Creating Azure Container Registry"
az deployment group create -g "$RG" -n opciq-acr \
  -f "$CLOUD_DIR/modules/registry.bicep" \
  -p name="$ACR_NAME" location="$LOCATION" 1>/dev/null
ACR_LOGIN_SERVER="$(az acr show -n "$ACR_NAME" -g "$RG" --query loginServer -o tsv)"

# 2) Build & push the three images with ACR Tasks (no local Docker needed).
echo "==> [2/6] Building images in ACR"
az acr build -r "$ACR_NAME" -t "opc-agents:${IMAGE_TAG}" \
  -f "$CLOUD_DIR/docker/agents.Dockerfile" "$REPO_ROOT"
az acr build -r "$ACR_NAME" -t "opc-mcp-dataiq:${IMAGE_TAG}" \
  -f "$CLOUD_DIR/docker/mcp-dataiq.Dockerfile" "$REPO_ROOT"
az acr build -r "$ACR_NAME" -t "opc-app:${IMAGE_TAG}" \
  -f "$CLOUD_DIR/docker/app.Dockerfile" "$REPO_ROOT"

# 3) Deploy the full infrastructure (Bicep is idempotent, re-declares the ACR).
echo "==> [3/6] Deploying infrastructure (Bicep)"
az deployment group create -g "$RG" -n opciq-main \
  -f "$CLOUD_DIR/main.bicep" \
  -p acrName="$ACR_NAME" location="$LOCATION" aksName="$AKS_NAME" imageTag="$IMAGE_TAG" 1>/dev/null

SESSION_POOL_ENDPOINT="$(az deployment group show -g "$RG" -n opciq-main --query properties.outputs.sessionPoolEndpoint.value -o tsv)"
WEB_APP_URL="$(az deployment group show -g "$RG" -n opciq-main --query properties.outputs.webAppUrl.value -o tsv)"
MCP_URL="$(az deployment group show -g "$RG" -n opciq-main --query properties.outputs.mcpUrl.value -o tsv)"
AGENTS_CLIENT_ID="$(az deployment group show -g "$RG" -n opciq-main --query properties.outputs.agentsIdentityClientId.value -o tsv)"
COMMUNICATION_SERVICE_NAME="$(az deployment group show -g "$RG" -n opciq-main --query properties.outputs.communicationServiceName.value -o tsv)"
ACS_EMAIL_SENDER_ADDRESS="$(az deployment group show -g "$RG" -n opciq-main --query properties.outputs.communicationEmailSenderAddress.value -o tsv)"
ACS_CONNECTION_STRING="$(az communication list-key \
  -g "$RG" \
  -n "$COMMUNICATION_SERVICE_NAME" \
  --query primaryConnectionString \
  -o tsv)"

if [[ -z "$ACS_CONNECTION_STRING" || -z "$ACS_EMAIL_SENDER_ADDRESS" ]]; then
  echo "ERROR: Azure Communication Services Email configuration was not returned by the deployment." >&2
  exit 1
fi

# 4) Deploy the agents workload to AKS (Entra ID auth via workload identity).
echo "==> [4/6] Deploying agents to AKS"
az aks get-credentials -g "$RG" -n "$AKS_NAME" --overwrite-existing
kubectl apply -f "$CLOUD_DIR/k8s/namespace.yaml"

# Non-secret Azure OpenAI settings (endpoint/model/version) from agents/.env.
# No API key is needed: the pod uses the federated managed identity.
if [[ ! -f "$REPO_ROOT/agents/.env" ]]; then
  echo "ERROR: $REPO_ROOT/agents/.env not found. Create it from agents/.env.example." >&2
  exit 1
fi
SECRET_ENV_FILE="$(mktemp)"
trap 'rm -f "$SECRET_ENV_FILE"' EXIT
grep -vE '^AZURE_COMMUNICATION_SERVICE_(CONNECTION_STRING|SENDER_ADDRESS)=' \
  "$REPO_ROOT/agents/.env" > "$SECRET_ENV_FILE"
printf 'AZURE_COMMUNICATION_SERVICE_CONNECTION_STRING=%s\n' "$ACS_CONNECTION_STRING" >> "$SECRET_ENV_FILE"
printf 'AZURE_COMMUNICATION_SERVICE_SENDER_ADDRESS=%s\n' "$ACS_EMAIL_SENDER_ADDRESS" >> "$SECRET_ENV_FILE"

kubectl -n opc-iq delete secret opc-agents-secret --ignore-not-found
kubectl -n opc-iq create secret generic opc-agents-secret --from-env-file="$SECRET_ENV_FILE"
rm -f "$SECRET_ENV_FILE"
trap - EXIT

# Federated service account (workload identity).
sed -e "s|__AGENTS_CLIENT_ID__|${AGENTS_CLIENT_ID}|g" \
    "$CLOUD_DIR/k8s/serviceaccount.yaml" | kubectl apply -f -

# Substitute placeholders and apply the workload.
sed -e "s|__ACR_LOGIN_SERVER__|${ACR_LOGIN_SERVER}|g" \
    -e "s|__IMAGE_TAG__|${IMAGE_TAG}|g" \
    -e "s|__SESSION_POOL_ENDPOINT__|${SESSION_POOL_ENDPOINT}|g" \
    "$CLOUD_DIR/k8s/agents-deployment.yaml" | kubectl apply -f -
kubectl apply -f "$CLOUD_DIR/k8s/agents-service.yaml"
kubectl -n opc-iq rollout restart deployment/opc-agents
kubectl -n opc-iq rollout status deployment/opc-agents --timeout=300s

# 5) Wait for the AKS LoadBalancer public IP.
echo "==> [5/6] Waiting for AKS agents public IP"
AGENTS_IP=""
for _ in $(seq 1 60); do
  AGENTS_IP="$(kubectl -n opc-iq get svc opc-agents -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)"
  [[ -n "$AGENTS_IP" ]] && break
  sleep 10
done
[[ -z "$AGENTS_IP" ]] && { echo "WARN: agents IP not ready yet; set AGENTS_BACKEND_URL later." >&2; }

# 6) Point the web app at the AKS agents backend.
if [[ -n "$AGENTS_IP" ]]; then
  echo "==> [6/6] Wiring web app -> http://${AGENTS_IP}"
  az containerapp update -g "$RG" -n "${PREFIX}-app" \
    --set-env-vars AGENTS_BACKEND_URL="http://${AGENTS_IP}" 1>/dev/null
fi

echo ""
echo "============================================================"
echo "Deployment complete."
echo "  Web app (ACA)      : ${WEB_APP_URL}"
echo "  MCP+dataIQ (ACA)   : ${MCP_URL}  (streamable-http)"
echo "  Agents (AKS)       : http://${AGENTS_IP:-<pending>}"
echo "  Sandbox pool (ACA) : ${SESSION_POOL_ENDPOINT}"
echo "  Email sender       : ${ACS_EMAIL_SENDER_ADDRESS}"
echo "============================================================"
