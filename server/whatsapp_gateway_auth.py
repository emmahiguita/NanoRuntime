"""Autenticación común del gateway: la llave de Nano no es el token de Meta."""

import hmac
import os

from fastapi import Header, HTTPException


def authenticate_gateway(
    api_key: str | None = Header(default=None, alias="X-Nano-API-Key"),
) -> None:
    """Compatibilidad de las lecturas existentes; nunca concede escritura por defecto."""
    authorize_gateway(api_key, "read")


def authorize_gateway(api_key: str | None, permission: str = "read") -> None:
    """Cada ruta declara su permiso; el cliente/modelo no puede elegir su propio rol."""
    fields = {"read": "NANO_WHATSAPP_API_KEY", "send": "NANO_WHATSAPP_SEND_KEY",
              "admin": "NANO_WHATSAPP_ADMIN_KEY"}
    values = {role: os.environ.get(field, "") for role, field in fields.items()}
    configured = {role: value for role, value in values.items() if 32 <= len(value) <= 256}
    if "read" not in configured or len(set(configured.values())) != len(configured):
        raise HTTPException(503, "Autenticación del gateway no configurada")
    if not isinstance(api_key, str) or not 32 <= len(api_key) <= 256:
        raise HTTPException(401, "Credencial de Nano no válida")
    # Compara todos los roles, sin registrar secreto ni terminar antes del último.
    roles = {role for role, value in configured.items() if hmac.compare_digest(
        api_key.encode("utf-8"), value.encode("utf-8"))}
    if not roles:
        raise HTTPException(401, "Credencial de Nano no válida")
    grants = {"read": {"read"}, "send": {"read", "send"}, "admin": {"read", "admin"}}
    if not any(permission in grants[role] for role in roles):
        raise HTTPException(403, "La llave Nano no permite esta operación")
