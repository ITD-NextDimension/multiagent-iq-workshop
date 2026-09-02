"""OPC multi-agent package (Microsoft Agent Framework).

AssistantAgent (queries the dataIQ OPC ontology through an MCP server) +
DataAnalystAgent (Monty CodeAct that renders charts) composed into a
sequential workflow.
"""

from .config import CHARTS_DIR, MCP_SERVER, create_chat_client
from .assistant_agent import create_assistant_agent, create_ontology_mcp_tool
from .data_analyst_agent import create_data_analyst_agent, render_chart_impl
from .workflow import build_workflow, run_pipeline

__all__ = [
    "CHARTS_DIR",
    "MCP_SERVER",
    "create_chat_client",
    "create_assistant_agent",
    "create_ontology_mcp_tool",
    "create_data_analyst_agent",
    "render_chart_impl",
    "build_workflow",
    "run_pipeline",
]
