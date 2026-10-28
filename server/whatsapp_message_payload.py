"""Valida ?nicamente los tipos oficiales admitidos por la interfaz de envío manual."""
import re
from fastapi import HTTPException


def message_body(payload):
    recipient = str(payload.get("to", ""))
    if not re.fullmatch(r"[1-9][0-9]{7,14}", recipient):
        raise HTTPException(422, "Usa el número internacional completo del destinatario")
    kind = payload.get("type", "text")
    result = {"messaging_product": "whatsapp", "recipient_type": "individual", "to": recipient, "type": kind}
    if kind == "text":
        text = str(payload.get("text", "")).strip()
        if not text or len(text) > 4096:
            raise HTTPException(422, "El texto debe tener entre 1 y 4096 caracteres")
        result["text"] = {"preview_url": False, "body": text}
    elif kind == "template":
        value = payload.get("template")
        if not isinstance(value, dict) or not re.fullmatch(r"[a-z0-9_]{1,512}", str(value.get("name", ""))):
            raise HTTPException(422, "Plantilla inválida")
        if not isinstance(value.get("language"), dict) or not value["language"].get("code"):
            raise HTTPException(422, "Falta idioma de la plantilla")
        result["template"] = value
    elif kind in {"image", "document", "audio", "video"}:
        value = payload.get(kind)
        if not isinstance(value, dict) or not re.fullmatch(r"[0-9]+", str(value.get("id", ""))):
            raise HTTPException(422, "Adjunta primero un archivo confirmado por Meta")
        result[kind] = {k: value[k] for k in ("id", "caption", "filename") if k in value}
        if kind == "audio":
            result[kind].pop("caption", None)
        if kind != "document":
            result[kind].pop("filename", None)
    else:
        raise HTTPException(422, "Tipo de envío no admitido")
    return result
