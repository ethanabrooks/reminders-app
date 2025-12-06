# Quick Start (Google Tasks)

Get GPT talking to Google Tasks in a few minutes.

## 1) Prepare credentials
1. In Google Cloud Console, enable the **Google Tasks API**.
2. Create OAuth client credentials (Desktop App).
3. Download `credentials.json` to the repo root.

## 2) Install deps
```bash
uv sync
```

## 3) Create `token.json` (one-time OAuth)
```bash
uv run python - <<'PY'
from pathlib import Path
from google_auth_oauthlib.flow import InstalledAppFlow

creds_path = Path("credentials.json")
flow = InstalledAppFlow.from_client_secrets_file(
    creds_path,
    scopes=["https://www.googleapis.com/auth/tasks"],
)
creds = flow.run_local_server(port=0)
Path("token.json").write_text(creds.to_json())
print("token.json written")
PY
```

Keep `token.json` private and out of version control.

## 4) Run the MCP server
```bash
uv run python server.py
# SSE endpoint: http://0.0.0.0:8000/sse/
```

## 5) Tools exposed
- `list_task_lists`
- `list_tasks` (status optional)
- `create_task`
- `update_task`
- `complete_task`
- `delete_task`

Use these tool names in your MCP-enabled client (e.g., ChatGPT custom GPT).

