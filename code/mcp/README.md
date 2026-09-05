# Enterprise Ontology MCP Server

A [Model Context Protocol](https://modelcontextprotocol.io) server that lets you quickly query
the enterprise ontology data under `dataIQ/` and, above all, the **relationships**
between the data — via natural language or tool calls.

It follows the four pillars from
[Fabric IQ Ontology Concepts](https://microsoft.github.io/Ontology-Playground/#/learn/ontology-fundamentals/fabric-iq-ontology-concepts):
**entity types**, **properties**, **identifier properties**, and **relationships & cardinality**.

## Data sources (all from `dataIQ/`)

| File | Purpose |
|---|---|
| `dataIQ/ontology/opc.rdf` | entity types / properties / relationships (RDF/OWL) |
| `dataIQ/bindings/data-bindings.json` | entity → data source and relationship key mappings |
| `dataIQ/data/*.json` | entity instances (mock data) |

The server parses these files into memory on startup, so **restart after changing the ontology or data** to pick up changes.

## Tools

| Tool | Description |
|---|---|
| `describe_ontology()` | Full ontology overview: entities, properties, identifier property, relationships & cardinality |
| `list_entity_types()` | List entity types with instance counts |
| `list_instances(entity_type, where_field?, where_value?)` | List/filter instances (e.g. projects with status=active) |
| `get_instance(entity_type, entity_id)` | Fetch a single instance by identifier |
| `get_related(entity_type, entity_id, relationship?)` | Traverse relationships both ways (e.g. a project's tasks, or the account funding a project) |
| `aggregate(entity_type, value_field, op, group_by?)` | Numeric aggregation (sum/avg/min/max/count, optional grouping) |

### Example questions → tools
- "Which projects are in progress?" → `list_instances("Project", "status", "active")`
- "Which tasks does PRJ-001 have?" → `get_related("Project", "PRJ-001", "has_task")`
- "Which account funds PRJ-002?" → `get_related("Project", "PRJ-002", "funds")`
- "Total budget by project status?" → `aggregate("Project", "budget", "sum", "status")`

## Environment and running

Use a virtual environment (Python 3.10-3.12):

```bash
# from code/
python3.12 -m venv .venv
source .venv/bin/activate
pip install -r mcp/requirements.txt

# Smoke test (no MCP client required)
python mcp/server.py --selftest

# Run as an MCP server (stdio)
python mcp/server.py
```

## Wire it into VS Code (`.vscode/mcp.json` already generated)

```jsonc
{
  "servers": {
    "opc-ontology": {
      "type": "stdio",
      "command": "${workspaceFolder}/code/.venv/bin/python",
      "args": ["${workspaceFolder}/code/mcp/server.py"]
    }
  }
}
```

> Paths are relative to the repository root, so `server.py` is under `code/mcp/`, not `mcp/`.
> On Windows work inside WSL, where the interpreter is `.venv/bin/python` as shown; a native
> Windows venv would use `.venv\\Scripts\\python.exe` instead.

## Wire it into Claude Desktop (`claude_desktop_config.json`)

```json
{
  "mcpServers": {
    "opc-ontology": {
      "command": "/path/to/multiagent-iq-workshop/code/.venv/bin/python",
      "args": ["/path/to/multiagent-iq-workshop/code/mcp/server.py"]
    }
  }
}
```
