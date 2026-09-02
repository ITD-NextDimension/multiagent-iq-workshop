"""FastAPI wrapper around the OPC multi-agent pipeline.

Run (from the agents/ folder, with the agentdev env active):

    uvicorn api:app --reload --port 8000

Endpoints:
    GET  /health           -> service status
    POST /ask              -> {question} => {answer, chart_url, transcript}
    GET  /charts/{name}    -> the generated PNG
    GET  /                 -> the Copilot-style chat web app (app/ folder)
"""

from __future__ import annotations

from pathlib import Path

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

from email_service import is_valid_email, send_result_email
from opc_agents.config import CHARTS_DIR
from opc_agents.workflow import run_pipeline

APP_DIR = Path(__file__).resolve().parent.parent / "app"

app = FastAPI(title="OPC Ontology Agents API", version="1.0.0")

# Allow the chat UI to call the API from any origin (useful when opened standalone).
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


class AskRequest(BaseModel):
    question: str


class AskResponse(BaseModel):
    question: str
    answer: str
    chart_url: str | None = None
    transcript: list[dict[str, str]]


class SendEmailRequest(BaseModel):
    email: str
    question: str
    answer: str
    chart_url: str | None = None


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok", "service": "opc-ontology-agents"}


@app.post("/ask", response_model=AskResponse)
async def ask(req: AskRequest) -> AskResponse:
    if not req.question.strip():
        raise HTTPException(status_code=400, detail="question must not be empty")
    result = await run_pipeline(req.question)
    chart_url = f"/charts/{result['chart_name']}" if result.get("chart_name") else None
    return AskResponse(
        question=result["question"],
        answer=result["answer"],
        chart_url=chart_url,
        transcript=result["transcript"],
    )


@app.post("/send-email")
def send_email(req: SendEmailRequest) -> dict[str, str]:
    recipient = req.email.strip()
    if not is_valid_email(recipient):
        raise HTTPException(status_code=400, detail="invalid email address")
    if not req.question.strip() or not req.answer.strip():
        raise HTTPException(status_code=400, detail="question and answer must not be empty")

    chart_path: Path | None = None
    if req.chart_url:
        chart_name = req.chart_url.removeprefix("/charts/")
        if (
            req.chart_url != f"/charts/{chart_name}"
            or "/" in chart_name
            or "\\" in chart_name
            or not chart_name.endswith(".png")
        ):
            raise HTTPException(status_code=400, detail="invalid chart URL")
        candidate = Path(CHARTS_DIR) / chart_name
        if not candidate.is_file():
            raise HTTPException(status_code=404, detail="chart not found")
        chart_path = candidate

    try:
        send_result_email(
            recipient=recipient,
            question=req.question.strip(),
            answer=req.answer.strip(),
            chart_path=chart_path,
        )
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=502, detail="Azure email delivery failed") from exc

    return {"status": "sent", "email": recipient}


@app.get("/charts/{name}")
def get_chart(name: str) -> FileResponse:
    # Prevent path traversal: only serve plain PNG file names.
    if "/" in name or "\\" in name or not name.endswith(".png"):
        raise HTTPException(status_code=400, detail="invalid chart name")
    path = Path(CHARTS_DIR) / name
    if not path.exists():
        raise HTTPException(status_code=404, detail="chart not found")
    return FileResponse(path, media_type="image/png")


# Serve the Copilot-style chat web app. Mounted last so the API routes above win.
if APP_DIR.exists():
    app.mount("/", StaticFiles(directory=str(APP_DIR), html=True), name="app")
