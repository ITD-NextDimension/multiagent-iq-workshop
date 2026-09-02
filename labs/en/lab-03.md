# Lab 03. Create Agents

## Story

Employees should not need to inspect source files or understand data joins. The AI transformation
team creates one agent to interpret enterprise questions and retrieve governed knowledge, then a
second agent to convert numerical findings into decision-ready charts. GitHub Copilot Coding Agent
helps implement the two agents and Microsoft Agent Framework orchestrates them.

## Architecture

```text
User question
  |
  v
AssistantAgent
  |  queries the dataIQ ontology through MCPStdioTool
  v
DataAnalystAgent
  |  calls render_chart through Monty CodeAct
  v
FastAPI response: answer + chart_url + transcript
```

Agent responsibilities:

| Agent | Responsibility | File |
|---|---|---|
| AssistantAgent | Uses MCP tools to answer project, account, and task relationship questions | [code/agents/opc_agents/assistant_agent.py](../../code/agents/opc_agents/assistant_agent.py) |
| DataAnalystAgent | Turns results into charts and saves PNG files | [code/agents/opc_agents/data_analyst_agent.py](../../code/agents/opc_agents/data_analyst_agent.py) |

## Lab Steps

1. Use GitHub Copilot Coding Agent to read [code/agents/README.md](../../code/agents/README.md) and confirm the two-agent goal.
2. Inspect [code/agents/opc_agents/workflow.py](../../code/agents/opc_agents/workflow.py) and understand the `AssistantAgent → DataAnalystAgent` sequential workflow.
3. Inspect [code/agents/api.py](../../code/agents/api.py) and confirm that the workflow is exposed through `POST /ask`.
4. Run `cd agents && python test_workflow.py --live "What is the total budget by project status? Draw a bar chart."` to validate the end-to-end agent response.
5. Check [code/agents/ontology_charts](../../code/agents/ontology_charts) and confirm that DataAnalystAgent generated a chart file.