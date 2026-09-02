# Lab 05. Cloud Architecture and One-Command Deployment

## Story

The AI Company prototype has demonstrated value, so the enterprise platform team must turn it into
a repeatable and governed cloud service. Employees need access from desktop and mobile, agents
need passwordless model access, code execution needs isolation, and business insights must be
shareable by email. The team describes the complete architecture in [code/cloud](../../code/cloud)
and automates delivery with one deployment script.

## Architecture

```text
Public users
  |
  v
Azure Container Apps: opciq-app
  |  reverse-proxies /ask, /charts, and /send-email
  v
AKS: opc-agents FastAPI + Microsoft Agent Framework
  |\
  | \-> Azure Container Apps Session Pool: Python sandbox
  |
  +-> Azure OpenAI / Foundry: Entra ID Workload Identity
  |
  +-> MCP + dataIQ: ontology query layer
  |
  +-> Azure Communication Services Email
        |  linked Azure-managed email domain
        v
      stakeholder inbox: answer + optional chart

Shared services: Azure Container Registry + Log Analytics
```

The deployment script [code/cloud/scripts/deploy.sh](../../code/cloud/scripts/deploy.sh) performs
6 stages: create ACR, build 3 immutable-tagged images with ACR Tasks, deploy the Bicep stack
including ACS Email and an Azure-managed domain, inject the generated connection string and sender
address into an AKS Secret, publish the AKS workload, wait for its public IP, and point the web app
at the API.

## Lab Steps

1. Open [code/cloud/README.md](../../code/cloud/README.md) and review AKS, Container Apps, ACR, Log Analytics, Workload Identity, and Azure Communication Services Email.
2. Inspect [code/cloud/main.bicep](../../code/cloud/main.bicep) and [code/cloud/modules/communicationEmail.bicep](../../code/cloud/modules/communicationEmail.bicep) to confirm that the Communication Service, Email Service, Azure-managed domain, and domain link are defined with Bicep.
3. Inspect [code/cloud/docker](../../code/cloud/docker) and [code/cloud/k8s](../../code/cloud/k8s) to confirm the three container images and AKS workload manifests.
4. Configure Azure OpenAI Endpoint, Model, and API Version in [code/agents/.env](../../code/agents/.env.example), then run `cd code/cloud && bash scripts/deploy.sh`. ACS Email is provisioned automatically; its credentials are not committed to `.env`.
5. Open the printed Web App URL, ask a business question, and send the result to a test mailbox. After the lab, run `bash scripts/teardown.sh` if the environment is no longer needed.

## Deployment Notes

- `deploy.sh` creates billable Azure resources.
- The cloud agents call Azure OpenAI with Entra ID through AKS Workload Identity, so `AZURE_OPENAI_API_KEY` is not required in the cloud.
- ACS Email uses an Azure-managed domain for workshop convenience. Production environments should use a verified custom domain and review email sending quotas.
- The ACS connection string and sender address are retrieved during deployment and stored in `opc-agents-secret`; they are never exposed to the browser.
- The Bicep files use a modular structure; sensitive values should use secure parameters or runtime secrets and should not be hard-coded in templates.
- If the AKS LoadBalancer IP is not ready immediately, rerun `bash scripts/deploy.sh` later to rewire the Web App.