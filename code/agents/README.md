# AI Company Multi-Agent Service (Microsoft Agent Framework)

A multi-agent system that answers questions using the `dataIQ` MCP service and generates charts
with Python, saving them as images.

- **AssistantAgent** — answers enterprise questions about projects, bank accounts, tasks and their
  relationships by calling the dataIQ ontology through MCP
  ([../mcp/server.py](../mcp/server.py)). Based on
  [samples/02-agents/mcp](https://github.com/microsoft/agent-framework/tree/main/python/samples/02-agents/mcp).
- **DataAnalystAgent** — uses Monty CodeAct (provider-owned tools) to turn the numbers in the
  answer into charts and save them as PNG. Based on
  [monty_code_act.py](https://github.com/microsoft/agent-framework/blob/main/python/samples/02-agents/context_providers/code_act/monty_code_act.py).
- **Workflow** — a `SequentialBuilder` chains the two agents as `AssistantAgent → DataAnalystAgent`.
  Based on
  [samples/03-workflows](https://github.com/microsoft/agent-framework/tree/main/python/samples/03-workflows).
- **Azure** — the agent is created with `OpenAIChatCompletionClient` (`azure_endpoint` + API key or
  `AzureCliCredential`); parameters live in `.env`. Based on
  [samples/02-agents/providers/azure](https://github.com/microsoft/agent-framework/tree/main/python/samples/02-agents/providers/azure).

> Note: the Monty sandbox cannot load C-extensions such as matplotlib, so the actual plotting runs
> in a **host tool** `render_chart`; the sandboxed code only calls `await render_chart(...)`. This
> is the recommended "provider-owned tools" pattern for Monty CodeAct.

## Directory layout

```
agents/
├── opc_agents/
│   ├── config.py             # loads .env and creates the Azure chat client
│   ├── assistant_agent.py    # AssistantAgent + MCPStdioTool(dataIQ)
│   ├── data_analyst_agent.py # DataAnalystAgent + MontyCodeActProvider + render_chart(matplotlib)
│   └── workflow.py           # SequentialBuilder: assistant -> analyst, run_pipeline()
├── api.py                    # FastAPI: /ask /charts/{name} /health, serves the chat web app
├── test_workflow.py          # offline tests + --live end-to-end test
├── ontology_charts/          # output directory for generated chart PNGs
├── requirements.txt
└── .env.example
```

## Architecture

```text
  User question
       |
       v
  AssistantAgent  --- MCP (stdio) --->  dataIQ MCP (opc.rdf + data/*.json)
       |
       |  SequentialBuilder
       v
  DataAnalystAgent  --- await render_chart --->  render_chart (matplotlib host tool)
                                                       |
                                                       v
                                              ontology_charts/*.png
```

## Setup

```bash
conda activate agentdev
pip install -r agents/requirements.txt

cp agents/.env.example agents/.env
# Edit agents/.env and set AZURE_OPENAI_ENDPOINT / AZURE_OPENAI_MODEL
# With an API key: set AZURE_OPENAI_API_KEY
# Or with Entra ID: leave the API key empty and run `az login`
# To email results, also set AZURE_COMMUNICATION_SERVICE_CONNECTION_STRING
# and AZURE_COMMUNICATION_SERVICE_SENDER_ADDRESS for Azure Communication Services Email.
```

## Testing

```bash
cd agents

# Offline tests (no Azure credentials): validate chart rendering + MCP tool discovery
python test_workflow.py

# End-to-end test (requires Azure credentials): full assistant -> analyst -> chart
python test_workflow.py --live "What is the total budget by project status? Draw a bar chart."
```

Offline tests already pass:
- `render_chart` produces a PNG
- All MCP tools discovered: `describe_ontology, list_entity_types, list_instances, get_instance, get_related, aggregate`

## Run as an API

```bash
cd agents
uvicorn api:app --port 8000
```

Request example:

```bash
curl -X POST http://127.0.0.1:8000/ask \
  -H "Content-Type: application/json" \
  -d '{"question": "Which projects does the business account fund, what is the total budget, draw a bar chart"}'
```

Response:

```json
{
  "question": "...",
  "answer": "The China Merchants Bank business account (ACC-001) funds PRJ-001 and PRJ-002, total budget 105000 CNY ...",
  "chart_url": "/charts/chart_20260720_142530_123456.png",
  "transcript": [{"author": "AssistantAgent", "text": "..."}]
}
```

Charts are available at `GET /charts/{name}`.

## Chat web app (Microsoft Copilot 365 style)

`../app/` is an HTML5 + CSS3 chat frontend (responsive for phone/desktop, with dark mode),
served directly by this API:

```bash
cd agents
uvicorn api:app --port 8000
# open http://127.0.0.1:8000/ in a browser
```

- The chat UI calls `POST /ask` and renders both the **text** answer and the **image**
  (the PNG referenced by `chart_url`).
- After each answer, the user can choose **Send to email**, enter a recipient, and send the
  answer (plus the generated chart as an attachment) through Azure Communication Services Email.
- The mobile-friendly AI Company frontend is plain static files ([app/index.html](../app/index.html),
  [app/styles.css](../app/styles.css), [app/app.js](../app/app.js)) with no framework dependency.
- CORS is enabled, so you can also deploy the frontend separately and point it at the backend via
  `window.AI_COMPANY_API_BASE` (the legacy `window.OPC_API_BASE` alias is still supported).
