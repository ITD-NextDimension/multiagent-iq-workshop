"""Send Copilot answers with Azure Communication Services Email."""

from __future__ import annotations

import base64
import html
import os
import re
from pathlib import Path

from azure.communication.email import EmailClient

EMAIL_PATTERN = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")


def is_valid_email(address: str) -> bool:
    return len(address) <= 254 and EMAIL_PATTERN.fullmatch(address) is not None


def send_result_email(
    *,
    recipient: str,
    question: str,
    answer: str,
    chart_path: Path | None = None,
) -> None:
    connection_string = os.getenv("AZURE_COMMUNICATION_SERVICE_CONNECTION_STRING", "").strip()
    sender_address = os.getenv("AZURE_COMMUNICATION_SERVICE_SENDER_ADDRESS", "").strip()
    if not connection_string or not sender_address:
        raise RuntimeError(
            "Azure Communication Services Email is not configured. Set "
            "AZURE_COMMUNICATION_SERVICE_CONNECTION_STRING and "
            "AZURE_COMMUNICATION_SERVICE_SENDER_ADDRESS."
        )

    safe_question = html.escape(question)
    safe_answer = html.escape(answer)
    message: dict[str, object] = {
        "senderAddress": sender_address,
        "recipients": {"to": [{"address": recipient}]},
        "content": {
            "subject": "Your AI Company Copilot result",
            "plainText": f"Question:\n{question}\n\nResult:\n{answer}",
            "html": (
                "<h2>AI Company Copilot result</h2>"
                f"<p><strong>Question</strong><br>{safe_question}</p>"
                f"<p><strong>Result</strong></p><pre style=\"white-space:pre-wrap\">{safe_answer}</pre>"
            ),
        },
    }

    if chart_path is not None:
        message["attachments"] = [
            {
                "name": chart_path.name,
                "contentType": "image/png",
                "contentInBase64": base64.b64encode(chart_path.read_bytes()).decode("ascii"),
            }
        ]

    result = EmailClient.from_connection_string(connection_string).begin_send(message).result()
    if str(result.get("status", "")).lower() != "succeeded":
        raise RuntimeError(f"Azure email delivery ended with status: {result.get('status', 'unknown')}")
