"""Recorre todos los lotes oficiales sin usar el primer elemento como atajo."""

import re

from .whatsapp_webhook_events import MetaInboxEvent, MetaWebhookScope, NormalizedWebhook


def _objects(value: object, location: str, issues: list[str]) -> list[tuple[int, dict]]:
    """Conserva índices originales y hermanos válidos; registra anomalías."""
    if not isinstance(value, list):
        issues.append(f"{location}: expected_list")
        return []
    result = []
    for index, item in enumerate(value):
        if isinstance(item, dict):
            result.append((index, item))
        else:
            issues.append(f"{location}[{index}]: expected_object")
    return result


def _timestamp(value: object) -> str | None:
    """No sustituye una fecha ausente por ahora; conserva epoch en segundos de Meta."""
    if isinstance(value, str) and re.fullmatch(r"[0-9]{1,12}", value):
        return value
    return None


def _event(
    item: dict, kind: str, settings: MetaWebhookScope, location: str, issues: list[str]
) -> MetaInboxEvent | None:
    """Normaliza identidad/estado y mantiene contenido, medios, errores y contexto."""
    wamid = item.get("id")
    # Coexistencia: En 'message' peer es 'from'; en 'echo' (humano en móvil) es 'to' o 'recipient_id'
    if kind == "echo":
        peer = item.get("to") or item.get("recipient_id")
    elif kind == "message":
        peer = item.get("from")
    else:
        peer = item.get("recipient_id")
    state = item.get("type") if kind in ("message", "echo") else item.get("status")
    if not isinstance(wamid, str) or not wamid or len(wamid) > 512:
        issues.append(f"{location}: invalid_wamid")
        return None
    if not isinstance(peer, str) or not re.fullmatch(r"[0-9]{1,32}", peer):
        issues.append(f"{location}: invalid_peer")
        return None
    if not isinstance(state, str) or not state or len(state) > 64:
        issues.append(f"{location}: invalid_type_or_status")
        return None
    timestamp = _timestamp(item.get("timestamp"))
    if timestamp is None:
        issues.append(f"{location}: missing_or_invalid_provider_timestamp")
    return MetaInboxEvent(
        kind,
        settings.waba_id,
        settings.phone_number_id,
        wamid,
        peer,
        timestamp,
        state,
        item,
    )


def normalize_webhook(payload: object, settings: MetaWebhookScope) -> NormalizedWebhook:
    """Solo WhatsApp y activos configurados; otros campos no se convierten en chats."""
    if (
        not isinstance(payload, dict)
        or payload.get("object") != "whatsapp_business_account"
    ):
        raise ValueError("El webhook no corresponde a WhatsApp Business")
    entries = payload.get("entry")
    if not isinstance(entries, list) or not entries:
        raise ValueError("El webhook requiere entry[]")
    issues: list[str] = []
    events: list[MetaInboxEvent] = []
    for entry_index, entry in _objects(entries, "entry", issues):
        location = f"entry[{entry_index}]"
        if entry.get("id") != settings.waba_id:
            raise PermissionError("WABA fuera del ámbito configurado")
        changes = _objects(entry.get("changes"), f"{location}.changes", issues)
        for change_index, change in changes:
            change_path = f"{location}.changes[{change_index}]"
            if change.get("field") != "messages":
                issues.append(f"{change_path}: unnormalized_field")
                continue
            value = change.get("value")
            if (
                not isinstance(value, dict)
                or value.get("messaging_product") != "whatsapp"
            ):
                issues.append(f"{change_path}: invalid_whatsapp_value")
                continue
            metadata = value.get("metadata")
            if not isinstance(metadata, dict) or not metadata.get("phone_number_id"):
                issues.append(f"{change_path}: missing_phone_number_id")
                continue
            if metadata["phone_number_id"] != settings.phone_number_id:
                raise PermissionError("Número Cloud fuera del ámbito configurado")
            for collection, kind in (
                ("messages", "message"),
                ("message_echoes", "echo"),
                ("statuses", "status"),
            ):
                if collection not in value:
                    continue
                path = f"{change_path}.{collection}"
                for index, item in _objects(value[collection], path, issues):
                    effective_kind = (
                        "echo"
                        if (kind == "message" and (item.get("is_echo") is True or item.get("type") == "echo"))
                        else kind
                    )
                    event = _event(item, effective_kind, settings, f"{path}[{index}]", issues)
                    if event is not None:
                        events.append(event)
            if "errors" in value:
                issues.append(f"{change_path}: provider_errors_preserved")
            if "messages" not in value and "message_echoes" not in value and "statuses" not in value:
                issues.append(f"{change_path}: no_message_or_status")
    return NormalizedWebhook(tuple(events), tuple(issues))
