"""Selección explícita de activos por línea, para las líneas del mismo propietario."""
import json
import os
import re
from contextvars import ContextVar
from fastapi import HTTPException
active_line = ContextVar("nano_whatsapp_line", default="default")


def configured_lines():
    try:
        values = json.loads(os.environ.get("META_WHATSAPP_LINES_JSON", "{}"))
        if not isinstance(values, dict):
            raise ValueError()
        for alias, value in values.items():
            if not re.fullmatch(r"[a-zA-Z0-9_-]{1,64}", alias) or not isinstance(value, dict):
                raise ValueError()
            if not all(re.fullmatch(r"[0-9]+", str(value.get(key, "")))
                       for key in ("waba_id", "phone_number_id")):
                raise ValueError()
        return values
    except (ValueError, TypeError):
        raise HTTPException(503, "Configuración de líneas Meta inválida") from None


def line_assets():
    alias = active_line.get()
    if alias == "default":
        return os.environ.get("META_WHATSAPP_WABA_ID", ""), os.environ.get("META_WHATSAPP_PHONE_NUMBER_ID", "")
    value = configured_lines().get(alias)
    if value is None:
        raise HTTPException(503, "L?nea pendiente de registro y configuración Meta")
    return str(value["waba_id"]), str(value["phone_number_id"])


def webhook_batches(payload):
    """La firma se verifica antes. Conserva cambios completos y rechaza líneas ajenas."""
    from .whatsapp_webhook_events import MetaWebhookScope
    from .whatsapp_webhook_normalizer import normalize_webhook
    allowed = {(str(v["waba_id"]), str(v["phone_number_id"])) for v in configured_lines().values()}
    default = (os.environ.get("META_WHATSAPP_WABA_ID", ""), os.environ.get("META_WHATSAPP_PHONE_NUMBER_ID", ""))
    if all(default):
        allowed.add(default)
    if not isinstance(payload, dict) or not isinstance(payload.get("entry"), list):
        raise ValueError("Webhook sin entradas válidas")
    result = []
    for entry in payload["entry"]:
        if not isinstance(entry, dict) or not isinstance(entry.get("changes"), list):
            raise ValueError("Entrada inválida")
        for change in entry["changes"]:
            value = change.get("value", {}) if isinstance(change, dict) else {}
            metadata = value.get("metadata", {}) if isinstance(value, dict) else {}
            scope = str(entry.get("id", "")), str(metadata.get("phone_number_id", ""))
            if scope not in allowed:
                raise PermissionError("Evento de línea no autorizada")
            result.append(normalize_webhook({**payload, "entry": [{**entry, "changes": [change]}]}, MetaWebhookScope(*scope)))
    return result
