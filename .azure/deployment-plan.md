# Azure Deployment Plan

> **Status:** Deployed

Generated: 2026-08-06 09:25 +08:00

---

## 1. Project Overview

**Goal:** Synchronize the new chat result email feature to the existing Azure deployment and configure Azure Communication Services Email end to end.

**Path:** Add Components to Existing Deployment

---

## 2. Requirements

| Attribute | Value |
|-----------|-------|
| Classification | Development / Demo |
| Scale | Small |
| Budget | Cost-Optimized |
| Subscription | CloudNative (`<subscription-id>`) - user confirmed |
| Resource Group | `rg-multiagent-iq` |
| Location | `swedencentral` for regional workloads; ACS control-plane resources use `global` with `Europe` data location - user confirmed |

---

## 3. Components Detected

| Component | Type | Technology | Path |
|-----------|------|------------|------|
| Chat frontend | Frontend | HTML/CSS/JavaScript | `code/app/` |
| Agents API | API | FastAPI/Python | `code/agents/` |
| Agent workload | Container | AKS | `code/cloud/k8s/` |
| Web frontend | Container | Azure Container Apps | `code/cloud/docker/app.Dockerfile` |
| Infrastructure | IaC | Bicep + Azure CLI script | `code/cloud/` |

---

## 4. Recipe Selection

**Selected:** Bicep + Azure CLI

**Rationale:** The existing production path is `code/cloud/main.bicep` orchestrated by `code/cloud/scripts/deploy.sh`. Reusing it avoids infrastructure drift and updates the existing AKS/Container Apps deployment.

---

## 5. Architecture

**Stack:** Existing AKS + Azure Container Apps deployment, extended with Azure Communication Services Email.

### Service Mapping

| Component | Azure Service | SKU / Mode |
|-----------|---------------|------------|
| Chat frontend | Azure Container Apps | Existing consumption environment |
| Agents API | Azure Kubernetes Service | Existing cluster |
| Email transport | Azure Communication Services | Global resource, Europe data location |
| Email domain | Email Communication Services | Azure-managed domain |
| Sender | ACS Azure-managed domain | `DoNotReply@<managed-domain>` |

### Planned Resource Names

| Resource | Name |
|----------|------|
| Communication Service | `opciq-acs-<unique-suffix>` |
| Email Communication Service | `opciq-email-<unique-suffix>` |
| Managed domain child resource | `AzureManagedDomain` |

### Security

- The browser only calls `/send-email`; ACS credentials remain server-side.
- The deployment script retrieves the ACS connection string after provisioning and stores it in the existing `opc-agents-secret` Kubernetes secret.
- No connection string or access key is committed to Git or emitted as a Bicep output.
- The Azure-managed domain avoids DNS credentials and verification steps.

---

## 6. Provisioning Limit Checklist

The `Microsoft.Communication` provider is registered. `az quota` returns `BadRequest` for this provider, so Azure Resource Graph and official ACS service-limit documentation were used as the supported fallback.

| Resource / Limit | Number to Deploy | Current | Total After Deployment | Limit / Quota | Notes |
|------------------|------------------|---------|------------------------|---------------|-------|
| `Microsoft.Communication/communicationServices` | 1 | 0 | 1 | No resource-count quota exposed by quota API | Provider registered; global resource type available |
| `Microsoft.Communication/emailServices` | 1 | 0 | 1 | No resource-count quota exposed by quota API | Global resource, Europe data location |
| `Microsoft.Communication/emailServices/domains` | 1 | 0 | 1 | One Azure-managed domain for this email service | Domain name `AzureManagedDomain` |
| Azure-managed domain sending rate | N/A | 0 | Application email traffic | 30 messages/minute, 100 messages/hour default sandbox rate | Official ACS service limits; sufficient for development/demo |

**Status:** All planned resources are within known limits. Azure-managed domains are intended for development/demo; production volume requires a custom verified domain and quota review.

---

## 7. Execution Checklist

### Phase 1: Planning

- [x] Analyze workspace
- [x] Gather requirements
- [x] Confirm subscription and location with user
- [x] Prepare resource inventory
- [x] Fetch quotas and validate capacity
- [x] Scan codebase
- [x] Select recipe
- [x] Plan architecture
- [x] User approved this plan

### Phase 2: Execution

- [x] Add ACS Email resources to Bicep
- [x] Update deployment script to retrieve ACS credentials and configure the AKS secret
- [x] Update deployment documentation
- [x] Run local functional verification
- [x] Update status to `Ready for Validation`

### Phase 3: Validation

- [x] Invoke azure-validate skill
- [x] Bicep compilation
- [x] Azure resource-group template validation
- [x] Azure what-if preview
- [x] Bicep linting
- [x] Azure authentication and policy check
- [x] Application syntax and offline tests
- [x] Email API behavior test
- [x] Static RBAC review
- [x] Populate Validation Proof
- [x] Status set to `Validated` by azure-validate

### Phase 4: Deployment

- [x] Invoke azure-deploy skill
- [x] Provision ACS Email and deploy updated images
- [x] Verify AKS rollout and public endpoints
- [x] Send a test email to `<test-recipient>`
- [x] Update status to `Deployed`

---

## 8. Validation Proof

| Check | Command Run | Result | Timestamp |
|-------|-------------|--------|-----------|
| Bicep compilation | `az bicep build --file code/cloud/main.bicep --stdout` | Pass | 2026-08-06 09:23 +08:00 |
| Template validation | `az deployment group validate -g rg-multiagent-iq -f code/cloud/main.bicep ...` | Pass (`Succeeded`) | 2026-08-06 09:24 +08:00 |
| What-if preview | `az deployment group what-if -g rg-multiagent-iq -f code/cloud/main.bicep ...` | Pass; creates only the three planned Communication resources, no deletes | 2026-08-06 09:24 +08:00 |
| Bicep lint | `az bicep lint --file code/cloud/main.bicep` | Pass | 2026-08-06 09:24 +08:00 |
| Authentication | `az account show` | Pass; CloudNative subscription enabled | 2026-08-06 09:24 +08:00 |
| Policy validation | `az policy assignment list --scope .../resourceGroups/rg-multiagent-iq` | Pass; no resource-group policy assignments blocking deployment | 2026-08-06 09:24 +08:00 |
| Application syntax | `bash -n`, `node --check`, `python -m py_compile` | Pass | 2026-08-06 09:23 +08:00 |
| Agent tests | `cd code/agents && python test_workflow.py` | Pass | 2026-08-06 09:23 +08:00 |
| Email API test | FastAPI `TestClient` with mocked ACS sender | Pass | 2026-08-06 09:24 +08:00 |
| Static RBAC review | Review `Microsoft.Authorization/roleAssignments` in Bicep | Pass; OpenAI User scoped to Foundry and AcrPull scoped to ACR; ACS uses server-side access key stored in Kubernetes Secret | 2026-08-06 09:24 +08:00 |

**Validated by:** azure-validate skill

**Validation timestamp:** 2026-08-06 09:24 +08:00

---

## 9. Files to Generate or Modify

| File | Purpose | Status |
|------|---------|--------|
| `.azure/deployment-plan.md` | Deployment source of truth | Complete |
| `code/cloud/modules/communicationEmail.bicep` | ACS Email, managed domain, and linked Communication Service | Complete |
| `code/cloud/main.bicep` | Include ACS module and non-secret outputs | Complete |
| `code/cloud/scripts/deploy.sh` | Put ACS connection string and sender address in AKS secret | Complete |
| `code/cloud/README.md` | Deployment and email configuration guidance | Complete |

---

## 10. Next Steps

Current phase: Deployed.

Deployment endpoints:

- Web app: `https://opciq-app.redocean-5a3532e6.swedencentral.azurecontainerapps.io`
- MCP: `https://opciq-mcp-dataiq.redocean-5a3532e6.swedencentral.azurecontainerapps.io`
- ACS sender: `DoNotReply@<acs-domain-id>.azurecomm.net`

The ACS send operation returned `Succeeded` through the deployed `/send-email` API.
