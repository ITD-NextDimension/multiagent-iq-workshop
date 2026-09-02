# MCP + dataIQ image (runs on Azure Container Apps as an HTTP MCP service).
# Build context = repository root.
FROM python:3.12-slim

WORKDIR /app

COPY mcp/requirements.txt /app/mcp/requirements.txt
RUN pip install --no-cache-dir -r /app/mcp/requirements.txt

COPY mcp /app/mcp
COPY dataIQ /app/dataIQ

ENV MCP_TRANSPORT=streamable-http
ENV PORT=8080
EXPOSE 8080
CMD ["python", "/app/mcp/server.py"]
