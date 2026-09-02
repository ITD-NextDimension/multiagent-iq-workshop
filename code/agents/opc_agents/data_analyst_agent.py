"""DataAnalystAgent: a Monty CodeAct agent that renders charts.

Follows the provider-owned Monty CodeAct pattern
(python/samples/02-agents/context_providers/code_act/monty_code_act.py): the model
sees a single ``execute_code`` tool and calls a provider-owned host tool from inside
the sandbox.

Because the Monty sandbox cannot import C-extensions such as matplotlib, the actual
plotting runs in a host tool (``render_chart``); the sandboxed code only calls
``await render_chart(...)`` with the numbers to visualize.
"""

from __future__ import annotations

from pathlib import Path
from typing import Annotated

import matplotlib

matplotlib.use("Agg")  # headless backend
import matplotlib.pyplot as plt  # noqa: E402

from agent_framework import Agent, tool  # noqa: E402
from agent_framework.openai import OpenAIChatCompletionClient  # noqa: E402
from agent_framework_monty import MontyCodeActProvider  # noqa: E402

from .config import CHARTS_DIR, create_chat_client  # noqa: E402

# Best-effort CJK fonts so Chinese labels render instead of tofu boxes.
plt.rcParams["font.sans-serif"] = [
    "PingFang SC", "Arial Unicode MS", "Heiti TC", "STHeiti",
    "Microsoft YaHei", "SimHei", "DejaVu Sans",
]
plt.rcParams["axes.unicode_minus"] = False

ANALYST_INSTRUCTIONS = (
    "You are a data analyst that visualizes numbers already present in the "
    "conversation. Write a SINGLE execute_code block that calls the host tool "
    "`render_chart` exactly once and prints the returned PNG path. "
    "Tool signature: render_chart(chart_type, title, labels, values, y_label='') "
    "where chart_type is 'bar', 'line' or 'pie'. Choose 'bar' for category "
    "comparisons, 'line' for time trends, 'pie' for share-of-total. Use ONLY the "
    "numbers provided in the conversation; never fabricate data. "
    "Example: `path = await render_chart(chart_type='bar', title='Project budget by status', "
    "labels=['active', 'done'], values=[105000, 25000], y_label='CNY'); print(path)`."
)


def render_chart_impl(
    chart_type: str,
    title: str,
    labels: list[str],
    values: list[float],
    y_label: str = "",
    basename: str = "chart",
) -> str:
    """Render a chart and save it as ``<CHARTS_DIR>/<basename>.png``. Returns the path.

    This is a plain function (no agent framework wrapper) so it can be unit-tested
    directly without invoking a model.
    """
    values = [float(v) for v in values]
    fig, ax = plt.subplots(figsize=(8, 5))

    if chart_type == "pie":
        ax.pie(values, labels=labels, autopct="%1.1f%%", startangle=90)
        ax.axis("equal")
    elif chart_type == "line":
        ax.plot(labels, values, marker="o", color="#0078D4")
        ax.set_ylabel(y_label)
        ax.grid(True, alpha=0.3)
    else:  # bar (default)
        ax.bar(labels, values, color="#107C10")
        ax.set_ylabel(y_label)
        for i, v in enumerate(values):
            ax.text(i, v, f"{v:g}", ha="center", va="bottom", fontsize=9)

    ax.set_title(title)
    if chart_type != "pie":
        plt.xticks(rotation=20, ha="right")

    path = Path(CHARTS_DIR) / f"{basename}.png"
    fig.savefig(path, dpi=150, bbox_inches="tight")
    plt.close(fig)
    return str(path)


def _make_render_chart_tool(basename: str):
    """Create a provider-owned ``render_chart`` tool bound to a chart basename."""

    @tool(approval_mode="never_require")
    def render_chart(
        chart_type: Annotated[str, "Chart type: 'bar', 'line', or 'pie'."],
        title: Annotated[str, "Chart title."],
        labels: Annotated[list[str], "Category labels."],
        values: Annotated[list[float], "Numeric values, same length as labels."],
        y_label: Annotated[str, "Y-axis label (ignored for pie)."] = "",
    ) -> str:
        """Render a chart from labels/values with matplotlib and save it as PNG.

        Returns the absolute path to the saved image.
        """
        return render_chart_impl(chart_type, title, labels, values, y_label, basename)

    return render_chart


def create_data_analyst_agent(
    client: OpenAIChatCompletionClient | None = None,
    chart_basename: str = "chart",
) -> Agent:
    """Build the DataAnalystAgent backed by a Monty CodeAct provider."""
    client = client or create_chat_client()
    codeact = MontyCodeActProvider(
        tools=[_make_render_chart_tool(chart_basename)],
        approval_mode="never_require",
    )
    return Agent(
        client=client,
        name="DataAnalystAgent",
        instructions=ANALYST_INSTRUCTIONS,
        context_providers=[codeact],
    )
