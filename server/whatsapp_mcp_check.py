"""Botón de diagnóstico MCP: el propietario lo activa en el panel privado."""

import asyncio

import httpx
from fastapi import HTTPException
from mcp import ClientSession
from mcp.client.streamable_http import streamable_http_client

from .whatsapp_local_server import LOCAL_URL
from .whatsapp_local_settings import load_settings
from .whatsapp_mcp import MCP_PATH
from .whatsapp_gateway_auth import authorize_gateway
from .whatsapp_check_result import CheckResult


async def _check() -> CheckResult:
    """Handshake y catálogo por HTTP real; no envía, lee chats ni consulta Meta."""
    settings = load_settings()
    headers = {"X-Nano-API-Key": settings.get("NANO_WHATSAPP_API_KEY", "")}
    async with asyncio.timeout(30):
        # Loopback no necesita proxy y la llave no sigue redirecciones.
        async with httpx.AsyncClient(headers=headers, trust_env=False,
                                     follow_redirects=False, timeout=25) as client:
            async with streamable_http_client(LOCAL_URL + MCP_PATH, http_client=client) as streams:
                async with ClientSession(streams[0], streams[1]) as session:
                    await session.initialize()
                    tools = (await session.list_tools()).tools
                    expected = {"whatsapp_get_conversations", "whatsapp_get_messages",
                                "whatsapp_get_changes", "whatsapp_get_templates"}
                    if {tool.name for tool in tools} != expected or not all(
                        tool.annotations and tool.annotations.readOnlyHint for tool in tools
                    ):
                        return CheckResult("error", "MCP respondió, pero su catálogo no coincide con las cuatro lecturas autorizadas.")
    # Revisa la llave REAL en el mismo autorizador que protege REST; sin POST ni fixtures.
    for permission in ("send", "admin"):
        try:
            authorize_gateway(settings.get("NANO_WHATSAPP_API_KEY", ""), permission)
        except HTTPException as error:
            if error.status_code != 403:
                return CheckResult("error", "MCP conectó, pero la separación de permisos no se pudo confirmar.")
        else:
            return CheckResult("error", "MCP conectó, pero su llave permite escritura: no la compartas.")
    return CheckResult("ok", "MCP autenticado: 4 lecturas; llave sin permiso de envío/edición. Recepción y entrega pendientes.")


def check_mcp_result() -> CheckResult:
    """El worker del panel maneja su event loop; no comparte hilos ni imprime claves."""
    try:
        return asyncio.run(_check())
    except Exception:
        return CheckResult("error", "MCP no validado. Revisa gateway iniciado, llave Nano y disponibilidad local.")


def check_mcp_readonly() -> str:
    """Compatibilidad con consumidores textuales; sin interpretar prefijos del mensaje."""
    return check_mcp_result().message
