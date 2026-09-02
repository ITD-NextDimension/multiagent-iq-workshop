"""Configuration and the Azure chat client factory.

Follows the Azure provider sample
(python/samples/02-agents/providers/azure): an ``OpenAIChatCompletionClient``
configured with ``azure_endpoint`` and either an API key or ``AzureCliCredential``.
All parameters are read from ``agents/.env``.
"""

from __future__ import annotations

import os
from pathlib import Path

from agent_framework.openai import OpenAIChatCompletionClient
from azure.identity import AzureCliCredential, DefaultAzureCredential
from dotenv import load_dotenv

# ---- paths ---------------------------------------------------------------- #
AGENTS_DIR = Path(__file__).resolve().parent.parent
REPO_ROOT = AGENTS_DIR.parent
MCP_SERVER = REPO_ROOT / "mcp" / "server.py"
CHARTS_DIR = AGENTS_DIR / "ontology_charts"
CHARTS_DIR.mkdir(exist_ok=True)

# Load agents/.env (does not override already-set environment variables).
load_dotenv(AGENTS_DIR / ".env")


def create_chat_client() -> OpenAIChatCompletionClient:
    """Create an Azure OpenAI chat client from environment variables.

    Required:
        AZURE_OPENAI_ENDPOINT   e.g. https://<resource>.openai.azure.com/
        AZURE_OPENAI_MODEL      the deployment name, e.g. gpt-4o-mini
    Optional:
        AZURE_OPENAI_API_VERSION (default 2024-10-21)
        AZURE_OPENAI_API_KEY     if set, key auth is used; otherwise an Entra ID
                                 credential is used (AzureCliCredential locally,
                                 AKS workload identity in the cloud).
    """
    endpoint = os.getenv("AZURE_OPENAI_ENDPOINT")
    model = os.getenv("AZURE_OPENAI_MODEL") or os.getenv("AZURE_OPENAI_CHAT_DEPLOYMENT_NAME")
    api_version = os.getenv("AZURE_OPENAI_API_VERSION", "2024-10-21")
    api_key = os.getenv("AZURE_OPENAI_API_KEY")

    if not endpoint or not model:
        raise RuntimeError(
            "Missing Azure OpenAI settings. Set AZURE_OPENAI_ENDPOINT and "
            "AZURE_OPENAI_MODEL in agents/.env (see .env.example)."
        )

    common = {"model": model, "azure_endpoint": endpoint, "api_version": api_version}
    if api_key:
        return OpenAIChatCompletionClient(api_key=api_key, **common)

    # No key: use an Entra ID credential. When AZURE_CLIENT_ID is present (injected
    # by AKS workload identity) DefaultAzureCredential uses the federated managed
    # identity; locally it falls back to AzureCliCredential (`az login`).
    if os.getenv("AZURE_CLIENT_ID") or os.getenv("AZURE_FEDERATED_TOKEN_FILE"):
        credential = DefaultAzureCredential()
    else:
        credential = AzureCliCredential()
    return OpenAIChatCompletionClient(credential=credential, **common)
