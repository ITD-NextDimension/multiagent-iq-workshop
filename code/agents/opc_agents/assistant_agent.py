"""AssistantAgent that answers enterprise questions via the dataIQ MCP server.

Follows the MCP agent sample (python/samples/02-agents/mcp): an ``MCPStdioTool``
spawns the local ``mcp/server.py`` (stdio) and exposes its ontology query tools
(``describe_ontology``, ``list_instances``, ``get_instance``, ``get_related``,
``aggregate``) to the agent.
"""

from __future__ import annotations

import sys

from agent_framework import Agent, MCPStdioTool
from agent_framework.openai import OpenAIChatCompletionClient

from .config import MCP_SERVER, create_chat_client

ASSISTANT_INSTRUCTIONS = (
    "You are the AI Company enterprise data assistant. "
    "Answer questions about the company's Projects, BankAccounts "
    "and Tasks, and the relationships between them, by calling the "
    "`opc_ontology` MCP tools: describe_ontology, list_entity_types, "
    "list_instances, get_instance, get_related, aggregate. "
    "Always ground every fact in tool results — never invent data. "
    "When the answer contains numbers that can be visualized (for example budget "
    "by status, or number of tasks per project), also present them explicitly as "
    "label/value pairs (e.g. 'active=105000, done=25000') so a downstream analyst "
    "can turn them into a chart."
)


def create_ontology_mcp_tool() -> MCPStdioTool:
    """Create the stdio MCP tool that runs the dataIQ enterprise ontology server."""
    return MCPStdioTool(
        name="opc_ontology",
        description=(
            "Query the AI Company enterprise ontology: projects, bank accounts, "
            "tasks, and their relationships (funds, has_task)."
        ),
        command=sys.executable,
        args=[str(MCP_SERVER)],
        approval_mode="never_require",
    )


def create_assistant_agent(
    client: OpenAIChatCompletionClient | None = None,
    mcp_tool: MCPStdioTool | None = None,
) -> Agent:
    """Build the AssistantAgent.

    Pass an already-connected ``mcp_tool`` when running inside a workflow so its
    stdio lifecycle is managed by the caller (``async with mcp_tool:``).
    """
    client = client or create_chat_client()
    mcp_tool = mcp_tool or create_ontology_mcp_tool()
    return Agent(
        client=client,
        name="AssistantAgent",
        instructions=ASSISTANT_INSTRUCTIONS,
        tools=mcp_tool,
    )
