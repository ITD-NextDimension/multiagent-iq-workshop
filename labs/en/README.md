# Enterprise AI Transformation Labs

An enterprise is starting an AI transformation program. Project, finance, account, and task data
is fragmented across systems, so employees and leaders cannot easily understand business status.
The goal is to build **AI Company**, an enterprise Copilot that connects operational knowledge,
answers grounded questions, produces visual analysis, and shares results with stakeholders.

## Lab Index

| Lab | Topic | File | Folder |
|---|---|---|---|
| 01 | Define the enterprise AI Copilot solution | [lab-01.md](lab-01.md) | [code/README.md](../../code/README.md) |
| 02 | Data architecture | [lab-02.md](lab-02.md) | [code/dataIQ](../../code/dataIQ) |
| 03 | Create Agents | [lab-03.md](lab-03.md) | [code/agents](../../code/agents) |
| 04 | Generate the app | [lab-04.md](lab-04.md) | [code/app](../../code/app) |
| 05 | Cloud architecture and one-command deployment | [lab-05.md](lab-05.md) | [code/cloud](../../code/cloud) |

## Base Environment

- macOS, Linux, or Windows WSL.
- Python 3.10-3.12 (3.12 recommended; 3.13 is not validated).
- Azure CLI with `az login` completed.
- `kubectl`.
- An Azure OpenAI or Azure AI Foundry model deployment.
- Access to the repository root: `multiagent-iq-workshop`.

Initialize locally:

```bash
cd code
python3.12 -m venv .venv
source .venv/bin/activate
pip install -r mcp/requirements.txt
pip install -r agents/requirements.txt
cp agents/.env.example agents/.env
```

Edit [code/agents/.env](../../code/agents/.env.example) and set at least:

```bash
AZURE_OPENAI_ENDPOINT=https://<resource>.openai.azure.com/
AZURE_OPENAI_MODEL=<deployment-name>
AZURE_OPENAI_API_VERSION=2024-10-21
```

For local passwordless auth, leave `AZURE_OPENAI_API_KEY` empty and rely on `az login`.

## Completion Criteria

After all 5 labs, the enterprise AI Company solution should have:

- A clear AI transformation story around enterprise projects, accounts, budgets, and tasks.
- A dataIQ/Fabric IQ-style data architecture queryable through MCP.
- Two Microsoft Agent Framework agents orchestrated as a workflow.
- A mobile-friendly AI Company Copilot web app.
- Email sharing through Azure Communication Services.
- A one-command Azure deployment path using Bicep, AKS, Container Apps, ACS Email, ACR, and Log Analytics.