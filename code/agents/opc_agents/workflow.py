"""Sequential workflow: AssistantAgent -> DataAnalystAgent.

Follows the workflow samples (python/samples/03-workflows): a ``SequentialBuilder``
chains the two agents so the assistant first answers the data question (via MCP),
then the analyst turns the resulting numbers into a saved chart.
"""

from __future__ import annotations

from datetime import datetime
from pathlib import Path
from typing import Any

from agent_framework.orchestrations import SequentialBuilder

from .assistant_agent import create_assistant_agent, create_ontology_mcp_tool
from .config import CHARTS_DIR, create_chat_client
from .data_analyst_agent import create_data_analyst_agent


def build_workflow(client=None, mcp_tool=None, chart_basename="chart"):
    """Assemble the sequential AssistantAgent -> DataAnalystAgent workflow.

    Returns the built workflow. The ``mcp_tool`` must already be connected
    (``async with mcp_tool:``) before the workflow is run.
    """
    client = client or create_chat_client()
    assistant = create_assistant_agent(client=client, mcp_tool=mcp_tool)
    analyst = create_data_analyst_agent(client=client, chart_basename=chart_basename)
    return SequentialBuilder(
        participants=[assistant, analyst],
        intermediate_output_from=[assistant],
    ).build()


async def run_pipeline(question: str, *, client=None) -> dict[str, Any]:
    """Run the full pipeline for a question and return the answer + chart path.

    The MCP stdio server lifecycle is managed here via ``async with mcp_tool``.
    """
    client = client or create_chat_client()
    chart_basename = f"chart_{datetime.now():%Y%m%d_%H%M%S_%f}"
    mcp_tool = create_ontology_mcp_tool()

    transcript: list[dict[str, str]] = []
    async with mcp_tool:  # spawn the dataIQ MCP server for the run
        workflow = build_workflow(client=client, mcp_tool=mcp_tool, chart_basename=chart_basename)
        agent = workflow.as_agent()
        response = await agent.run(question)

        for msg in getattr(response, "messages", []) or []:
            transcript.append(
                {"author": msg.author_name or str(msg.role), "text": msg.text or ""}
            )

    # The assistant's grounded answer (fall back to the final response text).
    answer = next(
        (m["text"] for m in reversed(transcript) if m["author"] == "AssistantAgent" and m["text"]),
        getattr(response, "text", "") or "",
    )

    chart_path = Path(CHARTS_DIR) / f"{chart_basename}.png"
    return {
        "question": question,
        "answer": answer,
        "chart_path": str(chart_path) if chart_path.exists() else None,
        "chart_name": f"{chart_basename}.png" if chart_path.exists() else None,
        "transcript": transcript,
    }
