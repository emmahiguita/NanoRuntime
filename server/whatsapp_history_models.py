"""Contrato de lectura separado de HTTP y SQLite; no representa entregas inventadas."""

import json
from typing import Protocol

from .whatsapp_webhook_events import MetaWebhookScope


class HistoryCursorExpired(ValueError):
    """Distingue una instantánea obsoleta de corrupción de datos persistidos."""


class WhatsAppHistoryReader(Protocol):
    """Puerto de lectura para la misma bandeja duradera que recibe el webhook."""

    def conversations(self, scope: MetaWebhookScope, limit: int,
                      before: int | None, through: int | None) -> dict: ...
    def messages(self, scope: MetaWebhookScope, peer: str, limit: int,
                 before: int | None, through: int | None) -> dict: ...
    def changes(self, scope: MetaWebhookScope, after: int, limit: int,
                through: int | None) -> dict: ...


def public_event(row) -> dict:
    """Expone contenido identificado, no el cuerpo firmado ni datos de otros chats."""
    payload = json.loads(row["payload_json"])
    kind = row["kind"]
    is_message = kind in ("message", "echo")
    message_type = row["provider_state"] if is_message else None
    content = payload.get(message_type) if message_type else None
    text = content.get("body") if message_type == "text" and isinstance(content, dict) else None
    caption = content.get("caption") if isinstance(content, dict) else None
    direction = "inbound" if kind == "message" else ("outbound" if kind == "echo" else None)
    return {
        "sequence": row["sequence"], "wamid": row["wamid"],
        "peer_id": row["peer_id"], "kind": kind,
        "direction": direction,
        "type": message_type, "text": text if isinstance(text, str) else None,
        "caption": caption if isinstance(caption, str) else None,
        "provider_timestamp": row["provider_timestamp"],
        "received_at_ms": row["received_at_ms"],
        "provider_state": row["provider_state"] if kind == "status" else None,
        "source": "meta_webhook",
    }
