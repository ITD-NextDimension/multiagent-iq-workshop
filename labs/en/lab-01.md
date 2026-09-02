# Lab 01. Define the Enterprise AI Copilot Solution

## Story

The enterprise AI transformation team starts with a common challenge: project delivery, financial
accounts, budgets, and tasks are stored in separate systems. Employees ask simple questions, but
answering them requires manual reconciliation. The team defines **AI Company**, an enterprise
Copilot that understands connected business context and turns it into grounded answers and actions.

## Architecture

```text
AI Company chat app
   |
   v
FastAPI /ask
   |
   v
Microsoft Agent Framework workflow
   |                         |
   v                         v
MCP ontology query service   chart rendering tool
   |
   v
dataIQ: Project / BankAccount / Task
```

The platform has 5 layers:

| Layer | Purpose | Folder |
|---|---|---|
| Copilot entry | Chat-based enterprise insight and sharing | [code/app](../../code/app) |
| API | Exposes `/ask`, `/send-email`, `/health`, and `/charts` | [code/agents/api.py](../../code/agents/api.py) |
| Agents | Understand questions, query the ontology, generate analysis | [code/agents/opc_agents](../../code/agents/opc_agents) |
| Data capability | MCP tools expose ontology and relationship queries | [code/mcp](../../code/mcp) |
| Business data | Enterprise ontology, bindings, and mock data | [code/dataIQ](../../code/dataIQ) |

## Lab Steps

1. Open [code/README.md](../../code/README.md) and understand the end-to-end enterprise Copilot architecture.
2. Inspect [code/dataIQ/data](../../code/dataIQ/data) and identify the enterprise `Project`, `BankAccount`, and `Task` data.
3. Run `python mcp/server.py --selftest` to verify that the MCP service can query the data relationships.
4. Run `cd agents && python test_workflow.py` to validate the offline agent workflow.
5. Record the transformation goal: provide a trusted enterprise insight Copilot locally first, then deploy it to Azure with [code/cloud/scripts/deploy.sh](../../code/cloud/scripts/deploy.sh).