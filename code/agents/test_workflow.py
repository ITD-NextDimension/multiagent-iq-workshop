"""Tests for the AI Company multi-agent pipeline.

Two layers:

* Offline tests (default) — validate chart rendering and MCP tool discovery.
  They do NOT need Azure OpenAI credentials and run fully locally.
      python test_workflow.py

* Live test — runs the full AssistantAgent -> DataAnalystAgent workflow against
  Azure OpenAI. Requires agents/.env to be filled in (and `az login` if using
  AzureCliCredential).
      python test_workflow.py --live "Total budget by project status, and draw a chart"
"""

from __future__ import annotations

import asyncio
import sys
from pathlib import Path

from opc_agents.assistant_agent import create_ontology_mcp_tool
from opc_agents.config import CHARTS_DIR
from opc_agents.data_analyst_agent import render_chart_impl


def test_render_chart() -> None:
    """The host matplotlib tool renders and saves a PNG."""
    path = Path(
        render_chart_impl(
            chart_type="bar",
            title="Project budget by status (test)",
            labels=["active", "done"],
            values=[105000, 25000],
            y_label="CNY",
            basename="test_offline_bar",
        )
    )
    assert path.exists() and path.stat().st_size > 0, "chart PNG was not created"
    print(f"[offline] render_chart OK -> {path}")


async def test_mcp_tools_available() -> None:
    """The MCP stdio tool connects to dataIQ and exposes the ontology tools."""
    tool = create_ontology_mcp_tool()
    async with tool:
        # After connecting, the loaded MCP functions are exposed on the tool.
        funcs = getattr(tool, "functions", None) or getattr(tool, "_functions", [])
        names = {getattr(f, "name", "") for f in funcs}
        assert names, "no MCP tools were discovered"
        expected = {"describe_ontology", "get_related", "aggregate"}
        missing = expected - names
        assert not missing, f"missing MCP tools: {missing}; got {sorted(names)}"
    print(f"[offline] MCP tools OK -> {sorted(names)}")


async def test_live(question: str) -> None:
    """Full workflow against Azure OpenAI."""
    from opc_agents.workflow import run_pipeline

    result = await run_pipeline(question)
    print("\n===== ANSWER =====")
    print(result["answer"])
    print("\n===== CHART =====")
    print(result["chart_path"] or "(no chart produced)")
    assert result["answer"], "empty answer"
    assert result["chart_path"], "no chart produced"
    assert Path(result["chart_path"]).exists()
    print("[live] pipeline OK")


async def _run_offline() -> None:
    print(f"charts dir: {CHARTS_DIR}")
    test_render_chart()
    await test_mcp_tools_available()
    print("\nAll offline tests passed ✅")


def main() -> None:
    if len(sys.argv) > 1 and sys.argv[1] == "--live":
        question = sys.argv[2] if len(sys.argv) > 2 else "What is the total budget by project status? Draw a bar chart."
        asyncio.run(test_live(question))
    else:
        asyncio.run(_run_offline())


if __name__ == "__main__":
    main()
