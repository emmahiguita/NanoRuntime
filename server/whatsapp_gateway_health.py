"""Diagnóstico local sin revelar credenciales ni confundir arranque con conexión Meta."""

import os

from fastapi import APIRouter, Request
from .whatsapp_line_scope import configured_lines

router = APIRouter()


@router.get("/api/v1/whatsapp/health")
async def gateway_health(request: Request):
    """Mide disponibilidad del proceso y configuración, NO validez remota del token."""
    outgoing = all(os.environ.get(key) for key in (
        "META_WHATSAPP_ACCESS_TOKEN", "META_GRAPH_API_VERSION", "NANO_WHATSAPP_API_KEY")) and bool(
            configured_lines() or (os.environ.get("META_WHATSAPP_WABA_ID") and os.environ.get("META_WHATSAPP_PHONE_NUMBER_ID")))
    incoming = bool(getattr(request.app.state, "meta_webhook_inbox", None)) and all(
        os.environ.get(key) for key in ("META_APP_SECRET", "META_WEBHOOK_VERIFY_TOKEN"))
    return {"service": "nano-whatsapp-gateway", "running": True,
            "outgoing_configured": outgoing, "webhook_configured": incoming,
            "meta_access_validated": False, "public_https_validated": False}
