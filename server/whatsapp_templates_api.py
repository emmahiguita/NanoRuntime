"""Gateway oficial: plantillas, texto saliente y bandeja firmada de WhatsApp."""

import asyncio
import os
import re
from typing import Any
from urllib.parse import urlencode

from fastapi import FastAPI, Header, HTTPException, Query

from .whatsapp_webhook_api import router as webhook_router
from .whatsapp_gateway_health import router as health_router
from .whatsapp_gateway_auth import authorize_gateway
from .whatsapp_line_scope import line_assets
from .whatsapp_message_payload import message_body
from .whatsapp_manual_outbox import reserve, accepted, save_outbound
from .whatsapp_media_transport import upload_media
from .whatsapp_webhook_security import webhook_database_path
from .whatsapp_webhook_store import SqliteWebhookInbox
import secrets
from .whatsapp_history_api import router as history_router
from .whatsapp_gateway_boundary import GatewayBoundary
from .whatsapp_graph_transport import _graph_request
from .whatsapp_mcp import MCP_PATH, McpGatewayEndpoint, gateway_lifespan

# Reutiliza el gateway existente; la entrada oficial no crea otro servicio/agente.
app = FastAPI(title="Nano WhatsApp Templates API", version="1.0.0",
              lifespan=gateway_lifespan, docs_url=None, redoc_url=None, openapi_url=None)
app.add_middleware(GatewayBoundary)
app.include_router(webhook_router)
app.include_router(health_router)
app.include_router(history_router)
# Ruta en el mismo gateway; el SDK no abre puertos ni lanza servidores auxiliares.
app.router.add_route(MCP_PATH, McpGatewayEndpoint(), methods=["GET", "POST", "DELETE"])
_TEMPLATE_NAME = re.compile(r"^[a-z0-9_]{1,512}$")
_GRAPH_VERSION = re.compile(r"^v[0-9]+\.[0-9]+$")
_FIELDS = "id,name,status,category,language,components"


def _settings(api_key: str | None, permission: str = "read") -> tuple[str, str, str]:
    """Valida secretos del servidor y autentica cada llamada de Nano."""
    authorize_gateway(api_key, permission)
    token = os.environ.get("META_WHATSAPP_ACCESS_TOKEN", "")
    waba, _ = line_assets()
    version = os.environ.get("META_GRAPH_API_VERSION", "")
    if not token or not waba or not _GRAPH_VERSION.fullmatch(version):
        raise HTTPException(503, "Cloud API no está configurada en el servidor")
    return token, waba, version


def _phone_number_id() -> str:
    """Exige el número de teléfono registrado para enviar por Cloud API."""
    _, value = line_assets()
    if not value.isdigit():
        raise HTTPException(503, "Cloud API requiere META_WHATSAPP_PHONE_NUMBER_ID")
    return value


def _template_payload(payload: dict[str, Any], editing: bool = False) -> dict:
    """Valida los campos que Nano controla; Meta valida reglas adicionales."""
    if not editing and not _TEMPLATE_NAME.fullmatch(str(payload.get("name", ""))):
        raise HTTPException(422, "El nombre debe usar minúsculas, números y guion bajo")
    if not editing and not re.fullmatch(r"[a-z]{2,3}(?:_[A-Z]{2})?", str(payload.get("language", ""))):
        raise HTTPException(422, "Usa un código de idioma Meta, por ejemplo es_CO")
    result = {key: payload[key] for key in ("name", "language", "category", "components") if key in payload}
    if result.get("category") not in {"MARKETING", "UTILITY", "AUTHENTICATION"}:
        raise HTTPException(422, "La categoría debe ser MARKETING, UTILITY o AUTHENTICATION")
    components = result.get("components")
    if not isinstance(components, list) or not components or not all(isinstance(item, dict) for item in components):
        raise HTTPException(422, "components debe ser una lista JSON de componentes Meta")
    return result


@app.get("/api/v1/whatsapp/templates")
async def list_templates(api_key: str | None = Header(default=None, alias="X-Nano-API-Key")):
    """Obtiene desde Meta plantillas y estados; nunca usa una lista de ejemplo."""
    token, waba, version = _settings(api_key)
    url = f"https://graph.facebook.com/{version}/{waba}/message_templates?fields={_FIELDS}&limit=100"
    return await asyncio.to_thread(_graph_request, "GET", url, token)


@app.post("/api/v1/whatsapp/templates")
async def create_template(payload: dict[str, Any], api_key: str | None = Header(default=None, alias="X-Nano-API-Key")):
    """Envía una plantilla nueva a Meta; su respuesta conserva estado real."""
    token, waba, version = _settings(api_key, "admin")
    data = _template_payload(payload)
    url = f"https://graph.facebook.com/{version}/{waba}/message_templates"
    return await asyncio.to_thread(_graph_request, "POST", url, token, data)


@app.put("/api/v1/whatsapp/templates/{template_id}")
async def update_template(template_id: str, payload: dict[str, Any], api_key: str | None = Header(default=None, alias="X-Nano-API-Key")):
    """Actualiza el recurso remoto solicitado usando su ID de Meta."""
    token, _, version = _settings(api_key, "admin")
    if not template_id.isdigit():
        raise HTTPException(422, "El ID de plantilla de Meta no es válido")
    data = _template_payload(payload, editing=True)
    if set(data) - {"category", "components"} or not data:
        raise HTTPException(422, "La edición solo acepta category y components")
    url = f"https://graph.facebook.com/{version}/{template_id}"
    return await asyncio.to_thread(_graph_request, "POST", url, token, data)


@app.delete("/api/v1/whatsapp/templates/{template_id}")
async def delete_template(template_id: str, name: str = Query(min_length=1), api_key: str | None = Header(default=None, alias="X-Nano-API-Key")):
    """Elimina en Meta por ID y nombre, como requiere el endpoint oficial."""
    token, waba, version = _settings(api_key, "admin")
    if not template_id.isdigit() or not _TEMPLATE_NAME.fullmatch(name):
        raise HTTPException(422, "El ID o nombre de plantilla no es válido")
    query = urlencode({"hsm_id": template_id, "name": name})
    url = f"https://graph.facebook.com/{version}/{waba}/message_templates?{query}"
    return await asyncio.to_thread(_graph_request, "DELETE", url, token)


@app.post("/api/v1/whatsapp/messages")
async def send_message(payload: dict[str, Any], api_key: str | None = Header(default=None, alias="X-Nano-API-Key")):
    """Envío manual idempotente. Nunca reenvía resultados inciertos a Meta."""
    token, waba, version = _settings(api_key, "send")
    phone = _phone_number_id()
    body = message_body(payload)
    request_id = str(payload.get("request_id", "")) or secrets.token_hex(24)
    if not re.fullmatch(r"[a-zA-Z0-9_-]{16,128}", request_id):
        raise HTTPException(422, "Identificador de solicitud inválido")
    path = webhook_database_path()
    scope = waba+":"+phone
    previous = await asyncio.to_thread(reserve, path, scope, request_id, body)
    response = {"messages": [{"id": previous}]} if previous else await asyncio.to_thread(
        _graph_request, "POST", f"https://graph.facebook.com/{version}/{phone}/messages", token, body)
    messages = response.get("messages", [])
    if not messages or not isinstance(messages[0], dict) or not messages[0].get("id"):
        raise HTTPException(502, "Resultado incierto; Meta no confirmó un ID. No se reenvió")
    await asyncio.to_thread(accepted, path, scope, request_id, messages[0]["id"])
    await asyncio.to_thread(save_outbound, SqliteWebhookInbox(path), waba, phone, request_id, body, response)
    return response


@app.post("/api/v1/whatsapp/media")
async def upload_attachment(payload: dict[str, Any], api_key: str | None = Header(default=None, alias="X-Nano-API-Key")):
    """Sube el archivo seleccionado; no inicia un envío ni programa acciones."""
    token, _, version = _settings(api_key, "send")
    return await asyncio.to_thread(upload_media, payload, token, _phone_number_id(), version)
