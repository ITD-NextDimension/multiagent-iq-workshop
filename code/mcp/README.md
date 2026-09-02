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

Use the `agentdev` conda environment (Python 3.12):

```bash
conda activate agentdev
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
      "command": "conda",
      "args": ["run", "-n", "agentdev", "python", "${workspaceFolder}/mcp/server.py"]
    }
  }
}
```

> If `conda run` is not on PATH, replace `command` with the absolute path to the agentdev
> Python (`conda activate agentdev && which python`).

## Wire it into Claude Desktop (`claude_desktop_config.json`)

```json
{
  "mcpServers": {
    "opc-ontology": {
      "command": "conda",
      "args": ["run", "-n", "agentdev", "python", "/path/to/AKS_MultiAgent_IQ/mcp/server.py"]
    }
  }
}
```
