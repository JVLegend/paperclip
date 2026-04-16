#!/bin/bash
# ============================================================
# DGX Ollama Auth Proxy + Cloudflared Tunnel Setup
# Run this ONCE on the DGX machine
# ============================================================
set -e

# ── Config — edit before running ────────────────────────────
TUNNEL_NAME="hermes-dgx"
CLOUDFLARE_DOMAIN="your-domain.com"          # e.g. jvlabs.com
DGX_SUBDOMAIN="dgx-ollama.your-domain.com"  # e.g. dgx-ollama.jvlabs.com
DGX_SECRET_KEY="${DGX_SECRET_KEY:-$(openssl rand -hex 32)}"
PROXY_PORT=11435
OLLAMA_PORT=11434

echo "======================================================"
echo "DGX Setup: Ollama Auth Proxy + Cloudflared Tunnel"
echo "======================================================"
echo "Secret key: ${DGX_SECRET_KEY}"
echo "Save this as DGX_SECRET_KEY in Railway!"
echo ""

# ── 1. Install dependencies ──────────────────────────────────
echo "[1/6] Installing dependencies..."
pip3 install fastapi uvicorn httpx 2>/dev/null || pip install fastapi uvicorn httpx

# ── 2. Create auth proxy ─────────────────────────────────────
echo "[2/6] Creating Ollama auth proxy..."
mkdir -p /opt/dgx-proxy

cat > /opt/dgx-proxy/proxy.py << 'PYPROXY'
#!/usr/bin/env python3
"""
Lightweight auth proxy for Ollama on DGX.
Validates Bearer token before forwarding to Ollama OpenAI-compatible API.
"""
import os
import asyncio
import httpx
from fastapi import FastAPI, Request, Response, HTTPException
from fastapi.responses import StreamingResponse

app = FastAPI(title="DGX Ollama Proxy")
OLLAMA_URL = os.environ.get("OLLAMA_URL", "http://localhost:11434")
SECRET_KEY = os.environ["DGX_SECRET_KEY"]

SKIP_HEADERS = {"host", "content-length", "transfer-encoding", "connection"}


def check_auth(request: Request):
    auth = request.headers.get("Authorization", "")
    if not auth.startswith("Bearer ") or auth[7:] != SECRET_KEY:
        raise HTTPException(status_code=401, detail="Unauthorized")


@app.get("/health")
async def health():
    return {"status": "ok", "proxy": "dgx-ollama"}


@app.api_route("/{path:path}", methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"])
async def proxy(path: str, request: Request):
    check_auth(request)
    url = f"{OLLAMA_URL}/{path}"
    headers = {
        k: v for k, v in request.headers.items()
        if k.lower() not in SKIP_HEADERS
    }
    # Remove auth header before forwarding (Ollama doesn't need it)
    headers.pop("authorization", None)

    body = await request.body()

    # Check if streaming is requested
    body_json = {}
    if body:
        import json
        try:
            body_json = json.loads(body)
        except Exception:
            pass

    is_streaming = body_json.get("stream", False)

    if is_streaming:
        async def stream_gen():
            async with httpx.AsyncClient(timeout=300) as client:
                async with client.stream(
                    request.method, url, headers=headers, content=body
                ) as resp:
                    async for chunk in resp.aiter_bytes():
                        yield chunk
        return StreamingResponse(stream_gen(), media_type="text/event-stream")
    else:
        async with httpx.AsyncClient(timeout=300) as client:
            resp = await client.request(
                method=request.method,
                url=url,
                headers=headers,
                content=body,
            )
        resp_headers = {
            k: v for k, v in resp.headers.items()
            if k.lower() not in SKIP_HEADERS
        }
        return Response(
            content=resp.content,
            status_code=resp.status_code,
            headers=resp_headers,
        )


if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PROXY_PORT", 11435))
    uvicorn.run(app, host="0.0.0.0", port=port, log_level="info")
PYPROXY

chmod +x /opt/dgx-proxy/proxy.py

# ── 3. Create systemd service for proxy ──────────────────────
echo "[3/6] Creating systemd service for auth proxy..."
cat > /etc/systemd/system/dgx-ollama-proxy.service << SYSTEMD
[Unit]
Description=DGX Ollama Auth Proxy
After=network.target ollama.service
Wants=ollama.service

[Service]
Type=simple
Environment=DGX_SECRET_KEY=${DGX_SECRET_KEY}
Environment=OLLAMA_URL=http://localhost:${OLLAMA_PORT}
Environment=PROXY_PORT=${PROXY_PORT}
ExecStart=/usr/bin/python3 /opt/dgx-proxy/proxy.py
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SYSTEMD

systemctl daemon-reload
systemctl enable dgx-ollama-proxy
systemctl start dgx-ollama-proxy
echo "   Proxy running on port ${PROXY_PORT}"

# ── 4. Install cloudflared ───────────────────────────────────
echo "[4/6] Installing cloudflared..."
if ! command -v cloudflared &>/dev/null; then
  curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 \
    -o /usr/local/bin/cloudflared
  chmod +x /usr/local/bin/cloudflared
fi
echo "   cloudflared $(cloudflared --version)"

# ── 5. Create named tunnel ───────────────────────────────────
echo "[5/6] Setting up cloudflared tunnel..."
echo ""
echo ">>> Run these commands MANUALLY (need browser auth):"
echo ""
echo "  cloudflared tunnel login"
echo "  cloudflared tunnel create ${TUNNEL_NAME}"
echo "  cloudflared tunnel route dns ${TUNNEL_NAME} ${DGX_SUBDOMAIN}"
echo ""
echo "Then get your TUNNEL_ID and update the config below:"

TUNNEL_ID="<paste-your-tunnel-id-here>"
mkdir -p /root/.cloudflared

cat > /root/.cloudflared/config.yml << CFCONFIG
tunnel: ${TUNNEL_ID}
credentials-file: /root/.cloudflared/${TUNNEL_ID}.json

ingress:
  - hostname: ${DGX_SUBDOMAIN}
    service: http://localhost:${PROXY_PORT}
  - service: http_status:404
CFCONFIG

# ── 6. Create systemd service for cloudflared ────────────────
echo "[6/6] Creating cloudflared systemd service..."
cat > /etc/systemd/system/cloudflared-dgx.service << SYSTEMD
[Unit]
Description=Cloudflared Tunnel (DGX Ollama)
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/cloudflared tunnel --config /root/.cloudflared/config.yml run
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
SYSTEMD

systemctl daemon-reload
# NOTE: enable only after adding tunnel credentials
# systemctl enable --now cloudflared-dgx

echo ""
echo "======================================================"
echo "DONE! Summary:"
echo "======================================================"
echo ""
echo "  Auth proxy: http://localhost:${PROXY_PORT}  (running)"
echo "  Tunnel URL: https://${DGX_SUBDOMAIN}/v1"
echo ""
echo "Railway env vars to set:"
echo "  DGX_SECRET_KEY = ${DGX_SECRET_KEY}"
echo "  DGX_BASE_URL   = https://${DGX_SUBDOMAIN}/v1"
echo ""
echo "After setting tunnel ID in /root/.cloudflared/config.yml:"
echo "  systemctl enable --now cloudflared-dgx"
echo ""
echo "Test with:"
echo "  curl -H 'Authorization: Bearer ${DGX_SECRET_KEY}' \\"
echo "       https://${DGX_SUBDOMAIN}/v1/models"
echo ""
