"""Borde HTTP del gateway: autentica antes de leer JSON y limita cuerpos y espera."""

import asyncio
import re

from fastapi import HTTPException
from starlette.responses import JSONResponse

from .whatsapp_gateway_auth import authorize_gateway
from .whatsapp_line_scope import active_line


# Solo se publica este API; no directorios, UI de escritorio ni documentación interna.
_WEBHOOK = "/api/v1/whatsapp/webhook"
_MCP = "/api/v1/whatsapp/mcp"
_READ = {
    "/api/v1/whatsapp/health", "/api/v1/whatsapp/conversations",
    "/api/v1/whatsapp/changes", "/api/v1/whatsapp/templates",
}


def _allowed(method: str, path: str) -> bool:
    """Lista cerrada: rutas nuevas requieren una decisión de publicación explícita."""
    if path == _WEBHOOK:
        return method in {"GET", "POST"}
    if path == _MCP:
        return method in {"GET", "POST", "DELETE"}
    if method == "GET":
        return path in _READ or bool(re.fullmatch(
            r"/api/v1/whatsapp/conversations/[0-9]{1,32}/messages", path
        ))
    if method == "POST":
        return path in {"/api/v1/whatsapp/messages", "/api/v1/whatsapp/media", "/api/v1/whatsapp/templates"}
    return method in {"PUT", "DELETE"} and bool(re.fullmatch(
        r"/api/v1/whatsapp/templates/[0-9]+", path
    ))


class GatewayBoundary:
    """Middleware ASGI sin servidor, tareas residentes ni almacenamiento adicional."""

    def __init__(self, app):
        self.app = app

    async def __call__(self, scope, receive, send):
        """El lifespan pasa intacto; HTTP no autorizado no alcanza parsers ni Graph."""
        if scope["type"] != "http":
            return await self.app(scope, receive, send)
        method, path = scope["method"], scope["path"]
        headers = {}
        for key, value in scope.get("headers", []):
            headers.setdefault(key.lower(), []).append(value)
        try:
            if not _allowed(method, path):
                raise HTTPException(404, "Ruta no publicada")
            if path not in {_WEBHOOK, "/api/v1/whatsapp/health"}:
                keys = headers.get(b"x-nano-api-key", [])
                # MCP Mobile usa Bearer. Es la llave Nano, jamás el token Meta.
                # Dos esquemas simultáneos se rechazan para evitar ambigüedad.
                if path == _MCP:
                    bearer = headers.get(b"authorization", [])
                    if keys and bearer:
                        raise HTTPException(401, "Usa una sola credencial Nano")
                    if not keys and len(bearer) == 1:
                        scheme, separator, credential = bearer[0].partition(b" ")
                        if separator and scheme.lower() == b"bearer":
                            keys = [credential]
                if len(keys) != 1:
                    raise HTTPException(401, "Credencial de Nano no válida")
                # Antes del parser: lectura no puede alcanzar envío ni edición.
                permission = "read"
                if path != _MCP and method != "GET":
                    permission = "send" if path in {"/api/v1/whatsapp/messages", "/api/v1/whatsapp/media"} else "admin"
                authorize_gateway(keys[0].decode("latin-1"), permission)
            if path == _WEBHOOK and method == "POST":
                signatures = headers.get(b"x-hub-signature-256", [])
                if len(signatures) != 1 or not re.fullmatch(
                    rb"sha256=[0-9a-fA-F]{64}", signatures[0]
                ):
                    raise HTTPException(403, "Firma de Meta ausente o inválida")
            limit = 9 * 1024 * 1024 if path == "/api/v1/whatsapp/media" else (4 * 1024 * 1024 if path == _WEBHOOK else 64 * 1024)
            lengths = headers.get(b"content-length", [])
            if len(lengths) > 1 or (lengths and not lengths[0].isdigit()):
                raise HTTPException(400, "Content-Length inválido")
            if lengths and int(lengths[0]) > limit:
                raise HTTPException(413, "Cuerpo supera el límite del gateway")
            # Bytes originales: no reserializa ni altera lo que verificará la firma HMAC.
            body = bytearray()
            async with asyncio.timeout(10):
                while True:
                    part = await receive()
                    if part["type"] == "http.disconnect":
                        return
                    if part["type"] != "http.request":
                        raise HTTPException(400, "Solicitud HTTP incompleta")
                    chunk = part.get("body", b"")
                    if len(body) + len(chunk) > limit:
                        raise HTTPException(413, "Cuerpo supera el límite del gateway")
                    body.extend(chunk)
                    if not part.get("more_body", False):
                        break
        except TimeoutError:
            return await self._error(scope, receive, send, 408, "Lectura HTTP incompleta")
        except HTTPException as error:
            return await self._error(scope, receive, send, error.status_code, error.detail)

        supplied = False

        async def original_body():
            """Entrega el cuerpo una sola vez; conserva notificación real de desconexión."""
            nonlocal supplied
            if not supplied:
                supplied = True
                return {"type": "http.request", "body": bytes(body), "more_body": False}
            return await receive()

        aliases = headers.get(b"x-nano-line-id", [])
        if len(aliases) > 1:
            return await self._error(scope, receive, send, 400, "Línea ambigua")
        alias = aliases[0].decode("ascii", errors="replace") if aliases else "default"
        if not re.fullmatch(r"[a-zA-Z0-9_-]{1,64}", alias):
            return await self._error(scope, receive, send, 400, "Línea inválida")
        token = active_line.set(alias)
        try:
            await self.app(scope, original_body, send)
        finally:
            active_line.reset(token)

    @staticmethod
    async def _error(scope, receive, send, status, detail):
        """Errores breves sin registrar cabeceras, llaves ni contenido de mensajes."""
        response = JSONResponse({"detail": detail}, status_code=status,
                                headers={"Cache-Control": "no-store"})
        await response(scope, receive, send)
