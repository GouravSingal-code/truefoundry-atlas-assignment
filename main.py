import httpx
import tiktoken
import os
from fastapi import FastAPI, Request
from fastapi.responses import StreamingResponse

app = FastAPI()

GATEWAY_URL    = os.environ["GATEWAY_URL"]          # AI Gateway base URL
GATEWAY_API_KEY = os.environ["GATEWAY_API_KEY"]     # TrueFoundry VAT or PAT
SMALL_THRESHOLD = int(os.environ.get("SMALL_THRESHOLD", "4096"))

def count_tokens(messages: list) -> int:
    enc = tiktoken.get_encoding("cl100k_base")
    return sum(
        len(enc.encode(m.get("content", "")))
        for m in messages
        if isinstance(m.get("content"), str)
    )

@app.get("/healthz")
async def health():
    return {"status": "ok"}

@app.post("/v1/chat/completions")
async def proxy(request: Request):
    body = await request.json()
    messages = body.get("messages", [])
    token_count = count_tokens(messages)
    bucket = "small" if token_count < SMALL_THRESHOLD else "large"

    headers = {
        "Authorization": f"Bearer {GATEWAY_API_KEY}",
        "Content-Type": "application/json",
        "x-tfy-metadata": f'{{"token_bucket": "{bucket}"}}',
    }
    body["model"] = "atlas-virtual-model/anthropic-openai"   # your Virtual Model name

    async with httpx.AsyncClient(timeout=120) as client:
        resp = await client.post(
            f"{GATEWAY_URL}/v1/chat/completions",
            json=body,
            headers=headers,
        )
    return StreamingResponse(
        iter([resp.content]),
        status_code=resp.status_code,
        media_type=resp.headers.get("content-type", "application/json"),
    )

