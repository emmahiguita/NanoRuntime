"""Contratos de entrada: evidencia del proveedor, no resultados inventados."""

import hashlib
import json
from dataclasses import dataclass
from typing import Protocol


# El normalizador recibe solo identidad autorizada, nunca secretos ni HTTP.
@dataclass(frozen=True)
class MetaWebhookScope:
    waba_id: str
    phone_number_id: str


# Cada evento conserva su ámbito; el nombre visible nunca identifica el chat.
@dataclass(frozen=True)
class MetaInboxEvent:
    kind: str
    waba_id: str
    phone_number_id: str
    wamid: str
    peer_id: str
    provider_timestamp: str | None
    state: str
    payload: dict

    @property
    def event_key(self) -> str:
        """Un mensaje es único por WAMID; cada estado conserva su propia evidencia."""
        parts = [self.waba_id, self.phone_number_id, self.kind, self.wamid]
        if self.kind == "status":
            parts.extend([self.state, self.provider_timestamp, self.peer_id])
        return hashlib.sha256(json.dumps(parts).encode("utf-8")).hexdigest()


# Los problemas se guardan junto al cuerpo firmado para poder reprocesarlo.
@dataclass(frozen=True)
class NormalizedWebhook:
    events: tuple[MetaInboxEvent, ...]
    issues: tuple[str, ...]


@dataclass(frozen=True)
class InboxReceipt:
    receipt_id: int
    inserted: int
    duplicates: int


class WebhookInbox(Protocol):
    """Puerto de persistencia: retornar exige que el commit ya haya terminado."""

    def save(self, raw: bytes, batch: NormalizedWebhook) -> InboxReceipt: ...
