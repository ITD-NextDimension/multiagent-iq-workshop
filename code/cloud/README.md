# AI Company Cloud Deployment (Azure, Bicep)

Deploys the AI Company enterprise Copilot to Azure. Everything is provisioned with **Bicep**,
into the existing resource group **`rg-multiagent-iq`** in **`swedencentral`**.

## Topology

```text
                         +------------------------------------------+
   Employees     ─────▶  |  ACA: AI Company (opciq-app) [nginx]    |
                         |  proxies /ask,/charts,/send-email        |
                         +---------------------┬--------------------+
                                               │  http://<AKS EXTERNAL-IP>
                                               ▼
                         +------------------------------------------+
                         |  AKS: aks-iq-aks-agent-hol               |
                         |  Deployment "opc-agents" (FastAPI)       |
                         |   AssistantAgent + DataAnalystAgent      |
                         |   Entra ID auth via Workload Identity    |
                         +----------┬--------------------┬----------+
                                    │ stdio MCP          │ code-exec offload
                                    │ (bundled)          ▼
                                    │        +--------------------------------+
                                    │        |  ACA session pool (sandbox)    |
                                    │        |  opciqsandbox  (PythonLTS)     |
                                    │        +--------------------------------+
                                    ▼
                         +------------------------------------------+
                         |  ACA: MCP + dataIQ (opciq-mcp-dataiq)    |
                         |  HTTP MCP service (streamable-http:8080) |
                         +------------------------------------------+
                                    |
                                    +------------------------------▶ Azure Communication
                                                                     Services Email

   Shared: Azure Container Registry + Log Analytics workspace
```

Mapping to the request:

| Request | Resource |
|---|---|
| App deployed with **AKS** | `aks-iq-aks-agent-hol` runs the agents workload (`cloud/k8s/`) |
| **agents** use an ACA **sandbox** node | `Microsoft.App/sessionPools` (dynamic sessions, PythonLTS) — see [azure-container-apps-sandboxes](https://github.com/Azure-Samples/azure-container-apps-sandboxes) |
| **dataIQ + MCP** on Azure Container Apps | `opciq-mcp-dataiq` container app (HTTP MCP + bundled dataIQ) |
| **AI Company app** on Azure Container Apps | `opciq-app` container app (mobile-friendly UI, proxies to AKS) |
| **Email sharing** | Azure Communication Services Email with an Azure-managed domain |
| Unified **Bicep** | `main.bicep` + `modules/` |

> Note: the AKS agents image also bundles `mcp/` + `dataIQ/`, so the agent's
> `MCPStdioTool` works in-process. The standalone `opciq-mcp-dataiq` ACA app
> exposes the same ontology over HTTP MCP for external clients. The session pool
> is provided to the agents as `ACA_SESSION_POOL_ENDPOINT` (the sandbox node for
> isolated code execution).

## Authentication

- **AKS agents → Azure OpenAI (Foundry):** passwordless **Entra ID** via AKS
  **Workload Identity**. A user-assigned managed identity (`opciq-agents-identity`)
  is federated to the `opc-agents-sa` service account and granted *Cognitive
  Services OpenAI User* on the Foundry account. The pod uses
  `DefaultAzureCredential`; **no `AZURE_OPENAI_API_KEY` is needed**. Local dev
  falls back to `AzureCliCredential`.
- **Container Apps → ACR:** the two ACA apps pull images using the **registry
  admin credentials** (a `passwordSecretRef` secret), which avoids the
  managed-identity `AcrPull` role-propagation race that can fail the first
  revision with `Operation expired`.
- **AKS → ACR:** the cluster's kubelet identity has `AcrPull` on the registry.
- **AKS agents → Azure Communication Services Email:** Bicep provisions an Azure-managed
  email domain. The deployment script retrieves the ACS connection string without printing it
  and stores it with the generated `DoNotReply@...azurecomm.net` address in `opc-agents-secret`.

## Files

```
cloud/
├── main.bicep                 # RG-scope orchestration
├── main.bicepparam            # parameters (reads ACR_NAME / IMAGE_TAG env)
├── modules/
│   ├── monitoring.bicep       # Log Analytics
│   ├── registry.bicep         # Azure Container Registry (admin user enabled)
│   ├── containerAppsEnv.bicep # ACA managed environment
│   ├── containerApp.bicep     # reusable container app (ACR admin-cred pull)
│   ├── sessionPool.bicep      # ACA dynamic sessions sandbox
│   ├── aks.bicep              # AKS cluster (+ OMS agent, OIDC + workload identity)
│   └── identity.bicep         # user-assigned MI + federated cred + OpenAI role
├── docker/
│   ├── agents.Dockerfile      # agents + mcp + dataIQ + app  -> AKS
│   ├── mcp-dataiq.Dockerfile  # MCP (HTTP) + dataIQ          -> ACA
│   └── app.Dockerfile         # nginx static UI              -> ACA
├── nginx/default.conf.template
├── k8s/
│   ├── namespace.yaml
│   ├── serviceaccount.yaml    # opc-agents-sa (workload-identity client id)
│   ├── agents-deployment.yaml
│   └── agents-service.yaml
└── scripts/
    ├── deploy.sh              # one-command end-to-end deploy
    └── teardown.sh
```

## Prerequisites

- Azure CLI logged in (`az login`) with rights on `rg-multiagent-iq`, plus the
  `containerapp` extension (`az extension add -n containerapp`).
- `kubectl`.
- `agents/.env` filled in with `AZURE_OPENAI_ENDPOINT`, `AZURE_OPENAI_MODEL`,
  and `AZURE_OPENAI_API_VERSION`. **No `AZURE_OPENAI_API_KEY` is required** —
  the deployed agents authenticate to Foundry with Entra ID via AKS Workload
  Identity. Azure Communication Services Email and its sender configuration are provisioned
  automatically and added to the AKS secret by `deploy.sh`.

## Deploy

```bash
cd cloud
bash scripts/deploy.sh
```

What `deploy.sh` does, end to end:

1. **[1/6]** Create the ACR (`registry.bicep`, admin user enabled).
2. **[2/6]** Build & push the three images with ACR Tasks (`opc-agents`,
   `opc-mcp-dataiq`, `opc-app`) using an immutable timestamp tag — no local Docker needed.
3. **[3/6]** Deploy the full Bicep stack (`main.bicep`): Log Analytics, ACS Email with an
   Azure-managed domain, ACA
   environment, the two container apps (pulling via ACR admin creds), the
   session-pool sandbox, the AKS cluster (OIDC + workload identity), and the
   federated managed identity with the *OpenAI User* role on Foundry.
4. **[4/6]** Deploy the agents to AKS: create the `opc-agents-secret` from
   `agents/.env` plus the generated ACS connection string and sender address, apply the workload-identity
   `opc-agents-sa` service account, the deployment, and the LoadBalancer service.
5. **[5/6]** Wait for the AKS LoadBalancer public IP.
6. **[6/6]** Point the web app at the AKS backend
   (`AGENTS_BACKEND_URL=http://<EXTERNAL-IP>`).

It prints the web app URL, MCP URL, AKS IP, and the sandbox endpoint.

> ⚠️ Running `deploy.sh` provisions billable Azure resources (AKS, ACA, ACR).

### Re-running / partial failures

`deploy.sh` is idempotent — re-running rebuilds images (cached layers are fast)
and re-applies the Bicep. If only the Bicep step needs to re-run (images already
built), you can deploy it directly:

```bash
az deployment group create -g rg-multiagent-iq -n opciq-main \
  --template-file cloud/main.bicep \
  -p location=swedencentral aksName=aks-iq-aks-agent-hol namePrefix=opciq \
     acrName=<acr-name> imageTag=latest foundryAccountName=my-ai-foundry
```

## Tear down

```bash
bash scripts/teardown.sh
```

Removes the created resources (the resource group `rg-multiagent-iq` itself is kept).
