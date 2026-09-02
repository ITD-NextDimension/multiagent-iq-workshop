# Agents workload image (runs on AKS).
# Bundles agents + mcp + dataIQ + app so the FastAPI service serves the chat UI,
# runs the multi-agent workflow, and spawns the MCP server over stdio.
# Build context = repository root.
FROM python:3.12-slim

WORKDIR /app

# Noto CJK fonts so matplotlib can render non-ASCII chart labels.
RUN apt-get update \
    && apt-get install -y --no-install-recommends fonts-noto-cjk \
    && rm -rf /var/lib/apt/lists/*

COPY agents/requirements.txt /app/agents/requirements.txt
COPY mcp/requirements.txt /app/mcp/requirements.txt
RUN pip install --no-cache-dir -r /app/agents/requirements.txt -r /app/mcp/requirements.txt

COPY agents /app/agents
COPY mcp /app/mcp
COPY dataIQ /app/dataIQ
COPY app /app/app

WORKDIR /app/agents
EXPOSE 8000
CMD ["uvicorn", "api:app", "--host", "0.0.0.0", "--port", "8000"]
