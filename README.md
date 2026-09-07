# AKS Multi-Agent IQ Workshop

> 中文版: [README.zh.md](README.zh.md)

This workshop follows an enterprise AI transformation program. A company has project, finance,
account, and task data spread across systems, making it difficult for employees and leaders to
understand operations through one trusted entry point. The team builds **AI Company**, an
enterprise insight Copilot that connects business data through an ontology, exposes governed
knowledge with MCP, analyzes it with Microsoft Agent Framework agents, and delivers answers,
charts, and email sharing through a cloud-hosted chat experience.

> **要讲这门课？** 从 [INSTRUCTOR.md](INSTRUCTOR.md) 开始 —— 从 T-7 天到课后清理的完整操作顺序。
> **是来上课的学员？** 先选一条环境准备路线：[Set Up Your Environment](#set-up-your-environment)。

## What You Will Build

By the end of the workshop, you will have an end-to-end enterprise insight Copilot:

```text
AI Company chat app
   |
   +--------------------+
   |                    |
   v                    v
FastAPI /ask       FastAPI /send-email
   |
   v
Microsoft Agent Framework workflow
   |                         |
   v                         v
MCP ontology tools        chart rendering
   |
   v
Enterprise ontology + Project / BankAccount / Task data
   |
   v
Azure deployment with AKS, Container Apps, ACS Email, ACR, and Log Analytics
```

The platform answers questions such as:

- Which accounts fund strategic projects?
- What is the total budget by project status?
- Which tasks and dependencies affect delivery?
- Email this insight and chart to a stakeholder.

## Workshop Labs

The workshop is split into 5 independent labs. Each lab includes the story, architecture, and up to 5 hands-on steps.

| Lab | Topic | English | Chinese |
|---|---|---|---|
| 01 | Define the enterprise AI transformation solution | [labs/en/lab-01.md](labs/en/lab-01.md) | [labs/cn/lab-01.md](labs/cn/lab-01.md) |
| 02 | Data architecture with dataIQ / Fabric IQ concepts | [labs/en/lab-02.md](labs/en/lab-02.md) | [labs/cn/lab-02.md](labs/cn/lab-02.md) |
| 03 | Create two Microsoft Agent Framework agents | [labs/en/lab-03.md](labs/en/lab-03.md) | [labs/cn/lab-03.md](labs/cn/lab-03.md) |
| 04 | Generate and run the web app | [labs/en/lab-04.md](labs/en/lab-04.md) | [labs/cn/lab-04.md](labs/cn/lab-04.md) |
| 05 | Cloud architecture and one-command deployment | [labs/en/lab-05.md](labs/en/lab-05.md) | [labs/cn/lab-05.md](labs/cn/lab-05.md) |

Lab indexes:

- [English lab index](labs/en/README.md)
- [Chinese lab index](labs/cn/README.md)

## Repository Structure

| Path | Purpose |
|---|---|
| [code/dataIQ](code/dataIQ) | Enterprise ontology, data bindings, mock data, and sample natural-language queries. The legacy sample file remains `opc.rdf`. |
| [code/mcp](code/mcp) | MCP server that exposes ontology and relationship query tools. |
| [code/agents](code/agents) | Microsoft Agent Framework workflow, FastAPI API, chart output, and tests. |
| [code/app](code/app) | Copilot-style HTML/CSS/JavaScript chat app. |
| [code/cloud](code/cloud) | Azure Bicep, Dockerfiles, Kubernetes manifests, and deployment scripts. |
| [labs/en](labs/en) | English workshop labs. |
| [labs/cn](labs/cn) | Chinese workshop labs. |

For the implementation-level README, see [code/README.md](code/README.md).

## Set Up Your Environment

Pick one of two routes. Both produce the same toolchain: Python 3.12, the 64 pinned
packages, Azure CLI, `kubectl`, and the VS Code extensions.

### Route A - GitHub Codespaces (recommended)

Nothing to install locally. On this repository, click **Code -> Codespaces -> Create
codespace on main**. Dependencies are baked into a prebuilt image, so the environment
opens without waiting for an install.

> Create the codespace **on this repository directly - do not fork first.** Prebuilds
> belong to a repository and a fork does not inherit them, so a codespace on your fork
> reinstalls all 64 packages from scratch. Fork or download afterwards if you want to
> keep your work.

You need a GitHub account and GitHub Copilot with Agent mode available. When Lab 03
asks for Azure OpenAI credentials, run `bash .devcontainer/set-key.sh` and paste the
values your instructor hands out.

The same `.devcontainer/` also works locally in VS Code with the Dev Containers
extension if you have Docker Desktop.

### Route B - Local install

Follow [Prerequisites](#prerequisites) and [Local Setup](#local-setup) below. The
[pre-class environment checklist](scripts/pre-request-check/00-学员环境清单.md) can
install and verify all of it for you on macOS, Linux/WSL, or Windows.

## Prerequisites

- macOS, Linux, or Windows WSL.
- Python 3.10-3.12 (3.12 recommended; 3.13 is not validated).
- Azure CLI with `az login` completed.
- `kubectl` for AKS deployment.
- An Azure OpenAI or Azure AI Foundry model deployment.
- Rights to create or update resources in the target Azure resource group.

## Local Setup

```bash
cd code
python3.12 -m venv .venv
source .venv/bin/activate
pip install -r mcp/requirements.txt
pip install -r agents/requirements.txt
cp agents/.env.example agents/.env
```

Edit `code/agents/.env` and set:

```bash
AZURE_OPENAI_ENDPOINT=https://<resource>.openai.azure.com/
AZURE_OPENAI_MODEL=<deployment-name>
AZURE_OPENAI_API_VERSION=2024-10-21
```

For local passwordless authentication, leave `AZURE_OPENAI_API_KEY` empty and rely on `az login`.

## Run Locally

> Every command below prints an `IncompleteFieldDefinitionWarning` about a `lifespan`
> field, emitted by `pydantic-settings` via the MCP SDK. It is harmless and the checks
> still pass — no action needed.

Validate the ontology and MCP tools:

```bash
cd code
python mcp/server.py --selftest
```

Run the agent workflow checks:

```bash
cd code/agents
python test_workflow.py
python test_workflow.py --live "What is the total budget by project status? Draw a bar chart."
```

Start the API and web app:

```bash
cd code/agents
uvicorn api:app --port 8000
```

Open `http://127.0.0.1:8000/` and ask AI Company about enterprise projects, accounts, budgets, or tasks.

## Deploy to Azure

The cloud deployment uses [code/cloud](code/cloud) to provision and deploy:

- Azure Kubernetes Service for the agents API workload.
- Azure Container Apps for the web app and HTTP MCP + dataIQ service.
- Azure Container Apps dynamic session pool for sandboxed code execution.
- Azure Container Registry for container images.
- Log Analytics for observability.
- AKS Workload Identity for passwordless Azure OpenAI / Foundry access.
- Azure Communication Services Email with an Azure-managed domain for sharing Copilot results.

Run the one-command deployment:

```bash
cd code/cloud
bash scripts/deploy.sh
```

The script builds the three container images with ACR Tasks, deploys the Bicep stack including
Azure Communication Services Email, publishes the AKS workload, injects the generated sender
configuration into a Kubernetes Secret, waits for the LoadBalancer IP, and points the web app at
the agents API.

> Running the deployment creates billable Azure resources.

To remove the workshop resources:

```bash
cd code/cloud
bash scripts/teardown.sh
```

## Learning Outcomes

After the workshop, you should understand how to:

- Model connected enterprise knowledge with dataIQ / Fabric IQ-style ontology concepts.
- Expose ontology relationships through MCP tools.
- Build a two-agent Microsoft Agent Framework workflow.
- Wrap the workflow as a mobile-friendly FastAPI and AI Company chat experience.
- Share answers and chart attachments through Azure Communication Services Email.
- Deploy the complete system to Azure with modular Bicep, AKS, Container Apps, ACS Email, and one execution script.