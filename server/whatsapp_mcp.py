"""Adaptador MCP de lectura sobre el gateway oficial, no un WhatsApp Web/QR."""

import os
import re
from contextlib import asynccontextmanager
from typing import Annotated

from fastapi import HTTPException, Response
from mcp.server.fastmcp import FastMCP
from mcp.server.fastmcp.exceptions import ToolError
from mcp.server.transport_security import TransportSecuritySettings
from mcp.types import ToolAnnotations
from pydantic import Field

from .whatsapp_history_api import _read
from .whatsapp_webhook_api import webhook_lifespan

MCP_PATH = "/api/v1/whatsapp/mcp"
Limit = Annotated[int, Field(ge=1, le=100)]
Cursor = Annotated[int | None, Field(ge=0, le=9223372036854775807)]
Peer = Annotated[str, Field(pattern=r"^[0-9]{1,32}$")]


async def _guard(operation, *args, **kwargs):
    """Error MCP auténtico, no respuesta vacía de éxito ni excepción privada cruda."""
    try:
        return await operation(*args, **kwargs)
    except HTTPException as error:
        # El transporte Graph ya limita detail a textos seguros sin cuerpo remoto.
        raise ToolError(f"Gateway HTTP {error.status_code}: {error.detail}") from None
    except Exception:
        raise ToolError("No se pudo completar la lectura oficial") from None


def create_mcp(app) -> FastMCP:
    """Solo lecturas. Host público exacto, sin desactivar protección DNS ni comodines Cloud."""
    hosts = ["127.0.0.1:*", "localhost:*"]
    origins = ["http://127.0.0.1:*", "http://localhost:*"]
    public_host = os.environ.get("NANO_WHATSAPP_PUBLIC_HOST", "")
    if public_host and re.fullmatch(r"[a-z0-9](?:[a-z0-9.-]*[a-z0-9])?", public_host):
        hosts.extend((public_host, public_host + ":443"))
        origins.append("https://" + public_host)
    mcp = FastMCP("Nano Meta WhatsApp", stateless_http=True, json_response=True,
                  streamable_http_path=MCP_PATH, log_level="WARNING",
                  transport_security=TransportSecuritySettings(
                      allowed_hosts=hosts, allowed_origins=origins))
    local_read = ToolAnnotations(readOnlyHint=True, destructiveHint=False,
                                 idempotentHint=True, openWorldHint=False)

    async def history(operation: str, *args):
        """Reutiliza lector, ámbito empresarial y controles SQLite del REST existente."""
        reader = getattr(app.state, "meta_history_reader", None)
        if reader is None:
            raise ToolError("Historial oficial no configurado")
        return await _guard(_read, Response(), getattr(reader, operation), *args)

    @mcp.tool(annotations=local_read)
    async def whatsapp_get_conversations(limit: Limit = 50, before: Cursor = None,
                                         through: Cursor = None) -> dict:
        """Lee conversaciones recibidas por webhook, paginadas; no recupera WhatsApp antiguo."""
        return await history("conversations", limit, before, through)

    @mcp.tool(annotations=local_read)
    async def whatsapp_get_messages(peer_id: Peer, limit: Limit = 50,
                                   before: Cursor = None, through: Cursor = None) -> dict:
        """Lee mensajes persistidos del interlocutor exacto, no una agenda o historial inventado."""
        return await history("messages", peer_id, limit, before, through)

    @mcp.tool(annotations=local_read)
    async def whatsapp_get_changes(after: Annotated[int, Field(ge=0, le=9223372036854775807)] = 0,
                                   limit: Limit = 100, through: Cursor = None) -> dict:
        """Obtiene eventos reales para reanudar sincronización, sin polling residente."""
        return await history("changes", after, limit, through)

    @mcp.tool(annotations=ToolAnnotations(readOnlyHint=True, destructiveHint=False,
                                        idempotentHint=True, openWorldHint=True))
    async def whatsapp_get_templates() -> dict:
        """Consulta plantillas reales de Meta mediante el mismo servicio oficial de Nano."""
        # Importación diferida evita dependencia circular al registrar rutas.
        from .whatsapp_templates_api import list_templates
        return await _guard(list_templates, api_key=os.environ.get("NANO_WHATSAPP_API_KEY", ""))

    return mcp


class McpGatewayEndpoint:
    """ASGI delegado: utiliza la instancia viva, incluso tras detener/reiniciar el panel."""

    async def __call__(self, scope, receive, send):
        # GatewayBoundary autentica ANTES de entrar aquí; nunca se publica por separado.
        transport = getattr(scope["app"].state, "whatsapp_mcp_http", None)
        if transport is None:
            from starlette.responses import JSONResponse
            return await JSONResponse({"detail": "MCP no iniciado"}, status_code=503)(scope, receive, send)
        await transport(scope, receive, send)


@asynccontextmanager
async def gateway_lifespan(app):
    """Una instancia SDK nueva por arranque: su session manager no admite reutilización."""
    async with webhook_lifespan(app):
        mcp = create_mcp(app)
        app.state.whatsapp_mcp_http = mcp.streamable_http_app()
        try:
            async with mcp.session_manager.run():
                yield
        finally:
            app.state.whatsapp_mcp_http = None
