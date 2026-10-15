"""Configuración y autenticidad de Meta, independientes de Graph saliente."""

import hashlib
import hmac
import os
import re
from dataclasses import dataclass, field
from pathlib import Path

from fastapi import HTTPException


# Una instancia atiende los activos explícitos del gateway; no infiere tenants.
@dataclass(frozen=True)
class WebhookSettings:
    app_secret: str = field(repr=False)
    verify_token: str = field(repr=False)
    waba_id: str
    phone_number_id: str


def webhook_settings() -> WebhookSettings:
    """Exige secretos solo del servidor y los mismos activos del envío Cloud."""
    values = WebhookSettings(
        os.environ.get("META_APP_SECRET", ""),
        os.environ.get("META_WEBHOOK_VERIFY_TOKEN", ""),
        os.environ.get("META_WHATSAPP_WABA_ID", ""),
        os.environ.get("META_WHATSAPP_PHONE_NUMBER_ID", ""),
    )
    if (
        not values.app_secret
        or len(values.verify_token) < 32
        or not re.fullmatch(r"[0-9]+", values.waba_id)
        or not re.fullmatch(r"[0-9]+", values.phone_number_id)
    ):
        raise HTTPException(503, "Webhook de Meta no configurado")
    return values


def webhook_database_path() -> Path | None:
    """Sin ruta no activa recepción; exige disco persistente, no memoria temporal."""
    value = os.environ.get("NANO_WHATSAPP_WEBHOOK_DB", "")
    if not value:
        return None
    path = Path(value)
    if not path.is_absolute() or not path.parent.is_dir() or path.is_dir():
        raise ValueError(
            "NANO_WHATSAPP_WEBHOOK_DB requiere archivo absoluto y directorio existente"
        )
    return path


def verify_subscription(mode: str, token: str, challenge: str, expected: str) -> None:
    """Devuelve el challenge únicamente tras comparar el token, sin registrarlo."""
    if (
        mode != "subscribe"
        or not challenge
        or len(challenge) > 4096
        or not hmac.compare_digest(token.encode("utf-8"), expected.encode("utf-8"))
    ):
        raise HTTPException(403, "Verificación de webhook rechazada")


def verify_signature(raw: bytes, signature: str, app_secret: str) -> None:
    """HMAC sobre bytes originales: nunca reserializa JSON antes de verificar."""
    if not re.fullmatch(r"sha256=[0-9a-fA-F]{64}", signature):
        raise HTTPException(403, "Firma de Meta ausente o inválida")
    expected = hmac.new(app_secret.encode("utf-8"), raw, hashlib.sha256).hexdigest()
    if not hmac.compare_digest(signature[7:].lower(), expected):
        raise HTTPException(403, "Firma de Meta inválida")
