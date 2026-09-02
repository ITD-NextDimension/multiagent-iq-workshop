# Lab 04. Generate the App

## Story

Employees and leaders need one mobile-friendly entry point for questions such as “Which accounts
fund strategic projects?”, “Which tasks affect delivery?”, and “What is the budget by project
status?” The team turns the API into the **AI Company** Copilot and adds an action for emailing an
answer and its chart to a stakeholder.

## Architecture

```text
app/index.html
app/styles.css
app/app.js
   |
   | POST /ask
   | POST /send-email
   v
agents/api.py
   |
   v
answer + chart_url + email delivery status
```

The application is served by [code/agents/api.py](../../code/agents/api.py) directly from the static files in [code/app](../../code/app). It has no frontend build dependency, so it works well for local validation and can also be packaged into a container for Azure Container Apps.

## Lab Steps

1. Open [code/app/index.html](../../code/app/index.html) and review the mobile-friendly AI Company page and sample prompts.
2. Open [code/app/app.js](../../code/app/app.js) and confirm that the page sends questions to `/ask`, renders `chart_url`, and offers the `/send-email` action after each answer.
3. Run `cd agents && uvicorn api:app --port 8000` to start the API and static web app.
4. Open `http://127.0.0.1:8000/` and ask “Which projects does the business account fund?”
5. Confirm that the page returns an answer and optional chart, then open **Send result to Email**, enter a recipient, and verify the delivery status.